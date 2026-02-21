function out = acc_test_closedloop_(pack)
% acc_test_closedloop_
% Timed closed-loop evaluation for ACC (absolute acceleration control).
%
% Methods (if provided in pack):
%   Opt        : OPbase_acc{xi,vdes} -> u
%   NN         : pure_nn_forward_alg_(Alg,[xi;vdes]) -> u
%   NN+Proj    : OPNNProj{xi, uhat} -> u
%   CertNet    : OPCertNet.cert_forward([xi;vdes]) -> u
%   CertNetRaw : OPCertNet_raw.cert_forward([xi;vdes]) -> u   (plot-only)
%   CERT       : OPCert.vertices([xi;vdes]) timing-only
%
% Outputs:
%   out.names, out.plot_only, out.time_us, out.occ_mean, out.occ_p99, out.miss_rate
%   out.vmax, out.vrate, out.hviol, out.hrate, out.track
%   out.u_traj, out.xi_traj

    maxNumCompThreads(1);

    % -------------------- unpack scalars --------------------
    nTest = pack.nTest; Ts_us = pack.Ts_us; epsf = pack.eps_feas;
    [Ts, cd, tau] = deal(pack.Ts, pack.cd, pack.tau);
    [umin, umax, vmin, vmax] = deal(pack.umin, pack.umax, pack.vmin, pack.vmax);
    [G, S, h] = deal(pack.G, pack.S, pack.h);

    xi0  = pack.xi0(:);
    VDES = pack.VdesTest(:);
    VL   = pack.VLTest(:);

    Wv = 1; Wu = 1e-2;
    if isfield(pack,'Wv') && ~isempty(pack.Wv), Wv = pack.Wv; end
    if isfield(pack,'Wu') && ~isempty(pack.Wu), Wu = pack.Wu; end

    if isfield(pack,'u_ref_fun') && ~isempty(pack.u_ref_fun)
        u_ref_fun = pack.u_ref_fun;
    else
        Kdes = 0.8;
        if isfield(pack,'Kdes') && ~isempty(pack.Kdes), Kdes = pack.Kdes; end
        u_ref_fun = @(xi, vdes, pack_) (Kdes*(vdes - xi(2)) + cd*xi(2));
    end

    % -------------------- availability flags --------------------
    use_qp = isfield(pack,'OPbase_acc')   && ~isempty(pack.OPbase_acc);
    use_nn = isfield(pack,'OPpureNNAlg') && ~isempty(pack.OPpureNNAlg);
    use_pr = use_nn && isfield(pack,'OPNNProj') && ~isempty(pack.OPNNProj);
    use_cn = isfield(pack,'OPCertNet')   && ~isempty(pack.OPCertNet);
    use_cr = isfield(pack,'OPCertNet_raw') && ~isempty(pack.OPCertNet_raw);
    use_ct = isfield(pack,'OPCert')      && ~isempty(pack.OPCert);

    names = {};
    if use_qp, names{end+1} = 'Opt'; end %#ok<AGROW>
    if use_nn, names{end+1} = 'NN'; end %#ok<AGROW>
    if use_pr, names{end+1} = 'NN+Proj'; end %#ok<AGROW>
    if use_cn, names{end+1} = 'CertNet'; end %#ok<AGROW>
    if use_cr, names{end+1} = 'CertNetRaw'; end %#ok<AGROW>
    if use_ct, names{end+1} = 'CERT'; end %#ok<AGROW>
    M = numel(names);

    col = struct();
    for j = 1:M
        col.(matlab.lang.makeValidName(names{j})) = j;
    end

    plot_only = false(M,1);
    if use_cr, plot_only(col.CertNetRaw) = true; end
    if use_ct, plot_only(col.CERT) = true; end

    % -------------------- outputs --------------------
    out = struct();
    out.nTest = nTest; out.Ts_us = Ts_us; out.eps_feas = epsf;
    out.names = names(:); out.plot_only = plot_only;

    out.time_us = nan(nTest,M);
    out.vmax    = nan(nTest,M);
    out.hviol   = nan(nTest,M);
    out.track   = nan(nTest,M);

    out.u_traj  = nan(nTest,M);
    out.xi_traj = nan(nTest+1,3,M);

    out.miss_rate = nan(M,1);
    out.occ_mean  = nan(M,1);
    out.occ_p99   = nan(M,1);
    out.vrate     = nan(M,1);
    out.hrate     = nan(M,1);

    % -------------------- localize operators (avoid pack. in loop) --------------------
    OPbase_acc    = [];
    OPpureNNAlg   = [];
    OPNNProj      = [];
    OPCertNet     = [];
    OPCertNet_raw = [];
    OPCert        = [];

    if use_qp, OPbase_acc = pack.OPbase_acc; end
    if use_nn, OPpureNNAlg = pack.OPpureNNAlg; end
    if use_pr, OPNNProj = pack.OPNNProj; end
    if use_cn, OPCertNet = pack.OPCertNet; end
    if use_cr, OPCertNet_raw = pack.OPCertNet_raw; end
    if use_ct, OPCert = pack.OPCert; end

    % -------------------- per-method states --------------------
    xi_qp = xi0; xi_nn = xi0; xi_pr = xi0; xi_cn = xi0; xi_cr = xi0; xi_ct = xi0;

    if use_qp, out.xi_traj(1,:,col.Opt) = xi_qp.'; end
    if use_nn, out.xi_traj(1,:,col.NN) = xi_nn.'; end
    if use_pr, out.xi_traj(1,:,col.NN_Proj) = xi_pr.'; end
    if use_cn, out.xi_traj(1,:,col.CertNet) = xi_cn.'; end
    if use_cr, out.xi_traj(1,:,col.CertNetRaw) = xi_cr.'; end
    if use_ct, out.xi_traj(1,:,col.CERT) = xi_ct.'; end

    % -------------------- warm-up (NOT timed) --------------------
    xi_w = xi0; xi_w(3) = VL(1);
    vdes_w = VDES(1);
    z_w = [xi_w; vdes_w];

    nW_fast = 300;
    nW_slow = 20;

    if use_cn
        for i = 1:nW_fast
            OPCertNet.cert_forward(z_w);
        end
    end
    if use_nn
        for i = 1:nW_fast
            pure_nn_forward_alg_(OPpureNNAlg, z_w);
        end
    end
    if use_ct
        for i = 1:nW_fast
            OPCert.vertices([xi_w; vdes_w]);
        end
    end
    if use_qp
        for i = 1:nW_slow
            OPbase_acc{xi_w, vdes_w};
        end
    end
    if use_pr
        for i = 1:nW_slow
            uhat_w = pure_nn_forward_alg_(OPpureNNAlg, z_w);
            OPNNProj{xi_w, uhat_w};
        end
    end

    % -------------------- main loop --------------------
    for k = 1:nTest
        vLk  = VL(k);
        vdes = VDES(k);

        if use_qp
            j = col.Opt;
            xi = xi_qp; xi(3) = vLk;
            rhs = h - S*xi;
            tt = tic; u = OPbase_acc{xi, vdes}; out.time_us(k,j) = 1e6*toc(tt);
            [xi_qp] = post_step_(k, j, xi, rhs, double(u), vdes);
        end

        if use_nn
            j = col.NN;
            xi = xi_nn; xi(3) = vLk;
            rhs = h - S*xi;
            tt = tic; u = pure_nn_forward_alg_(OPpureNNAlg, [xi; vdes]); out.time_us(k,j) = 1e6*toc(tt);
            [xi_nn] = post_step_(k, j, xi, rhs, double(u), vdes);
        end

        if use_pr
            j = col.NN_Proj;
            xi = xi_pr; xi(3) = vLk;
            rhs = h - S*xi;
            tt = tic;
            uhat = pure_nn_forward_alg_(OPpureNNAlg, [xi; vdes]);
            u = OPNNProj{xi, uhat};
            out.time_us(k,j) = 1e6*toc(tt);
            [xi_pr] = post_step_(k, j, xi, rhs, double(u), vdes);
        end

        if use_cn
            j = col.CertNet;
            xi = xi_cn; xi(3) = vLk;
            rhs = h - S*xi;
            tt = tic; u = OPCertNet.cert_forward([xi; vdes]); out.time_us(k,j) = 1e6*toc(tt);
            [xi_cn] = post_step_(k, j, xi, rhs, double(u), vdes);
        end

        if use_cr
            j = col.CertNetRaw;
            xi = xi_cr; xi(3) = vLk;
            rhs = h - S*xi;
            tt = tic; u = OPCertNet_raw.cert_forward([xi; vdes]); out.time_us(k,j) = 1e6*toc(tt);
            [xi_cr] = post_step_(k, j, xi, rhs, double(u), vdes);
        end

        if use_ct
            j = col.CERT;
            xi = xi_ct; xi(3) = vLk;
            tt = tic; OPCert.vertices([xi; vdes]); out.time_us(k,j) = 1e6*toc(tt);
        end
    end

    % -------------------- aggregate stats --------------------
    for j = 1:M
        t = out.time_us(:,j);
        occ = t / Ts_us;
        out.occ_mean(j)  = mean(occ,'omitnan');
        out.occ_p99(j)   = prctile(occ(~isnan(occ)),99);
        out.miss_rate(j) = mean(t > Ts_us,'omitnan');
        out.vrate(j)     = mean(out.vmax(:,j) > epsf,'omitnan');
        out.hrate(j)     = mean(out.hviol(:,j) > epsf,'omitnan');
    end

    % -------------------- local helpers --------------------
    function xi1 = post_step_(k, j, xi, rhs, u, vdes)
        u = min(max(u, umin), umax);
        out.vmax(k,j) = max([0; G*u - rhs]);
        % res = G*u - rhs;                      % m×1 raw residuals (positive => constraint violation)
        % Ai_inf = max(abs(G), [], 2);          % m×1 row-wise infinity norms: ||G_i||_inf
        % si = max([Ai_inf, abs(rhs), ones(size(rhs))], [], 2);  % m×1 scaling: s_i = max(||G_i||_inf, |rhs_i|, 1)
        % 
        % res_s = res ./ si;                    % m×1 normalized residuals (positive => normalized violation)
        % out.vmax(k,j) = max(0, max(res_s));   % scalar max normalized positive violation (0 if all satisfied)

        [xi1, hk1] = acc_step_(xi, u, Ts, cd, tau);
        out.hviol(k,j) = max(0, -hk1);

        u_ref = u_ref_fun(xi, vdes, pack);
        v1 = xi1(2);
        out.track(k,j) = Wv*(v1 - vdes)^2 + Wu*(u - u_ref)^2;

        out.u_traj(k,j) = u;
        out.xi_traj(k+1,:,j) = xi1.';
    end

    function [xi1, hk1] = acc_step_(xi, u, Ts, cd, tau)
        D = xi(1); v = xi(2); vL = xi(3);
        D1 = D + Ts*(vL - v);
        v1 = (1 - Ts*cd)*v + Ts*u;
        xi1 = [D1; v1; vL];
        hk1 = D1 - tau*v1;
    end
end
