function pack = mpqp_build_baseline_(Prob, cfg)
% mpqp_build_baseline_
% Build baseline OP objects + optional PureNN layer graph for ONE problem.
%
% Prob must contain (interface form):
%   Hard:  G*u <= h - S*xi
%   Soft:  Gsoft*u <= hsoft - Ssoft*xi - Tsoft*eta + s, s>=0
%
% Output pack:
%   .OPbase   : optimizer({xi, eta}) -> u
%   .OPPWA    : explicit PWA (optional)
%   .pwaNr, .pwaStatus
%   .OPNNProj : optimizer({xi, uhat}) -> u_proj  (hard projection)
%   .PureNNlayers (optional)

    if nargin < 2, cfg = struct(); end
    cfg = fill_cfg_(cfg);

    nu   = Prob.nu;
    nxi  = Prob.nxi;
    neta = Prob.neta;

    G     = Prob.G;     S     = Prob.S;     h     = Prob.h;
    Gsoft = Prob.Gsoft; Ssoft = Prob.Ssoft; Tsoft = Prob.Tsoft; hsoft = Prob.hsoft;

    H    = Prob.H;    F    = Prob.F;    Feta = Prob.Feta;    f = Prob.f;

    % -------------------- sanity checks (important after z=[xi;u] change) --------------------
    assert(size(G,2)     == nu,  'Prob.G must be mH×nu.');
    assert(size(S,2)     == nxi, 'Prob.S must be mH×nxi.');
    assert(numel(h)      == size(G,1), 'Prob.h length must match rows of G.');

    assert(size(Gsoft,2) == nu,  'Prob.Gsoft must be mS×nu.');
    assert(size(Ssoft,2) == nxi, 'Prob.Ssoft must be mS×nxi.');
    assert(size(Tsoft,2) == neta,'Prob.Tsoft must be mS×neta.');
    assert(numel(hsoft)  == size(Gsoft,1), 'Prob.hsoft length must match rows of Gsoft.');

    assert(all(size(H) == [nu,nu]), 'Prob.H must be nu×nu.');
    assert(all(size(F) == [nu,nxi]), 'Prob.F must be nu×nxi.');
    assert(all(size(Feta) == [nu,neta]), 'Prob.Feta must be nu×neta.');
    assert(numel(f) == nu, 'Prob.f must be nu×1.');

    pack = struct();
    pack.OPbase        = [];
    pack.OPPWA         = [];
    pack.pwaNr         = 0;
    pack.pwaStatus     = "skip";
    pack.OPNNProj      = [];
    pack.PureNNlayers  = [];

    % ------------------------------ OPbase (QP with slack) ------------------------------
    ops_qp = sdpsettings('solver', cfg.solver, 'verbose', cfg.verbose);

    ms  = numel(hsoft);
    u   = sdpvar(nu,1);
    xi  = sdpvar(nxi,1);
    eta = sdpvar(neta,1);
    s   = sdpvar(ms,1);

    C = [ ...
        G*u     <= h     - S*xi; ...
        Gsoft*u <= hsoft - Ssoft*xi - Tsoft*eta + s; ...
        s >= 0 ...
    ];

    J = 0.5*u'*H*u + (F*xi + Feta*eta + f)'*u + cfg.rho*sum(s) + cfg.eps_s*(s'*s);

    pack.OPbase = optimizer(C, J, ops_qp, {xi, eta}, u);

    % ------------------------------ Explicit PWA (optional) ------------------------------
    if cfg.enablePWA
        z = [xi; eta];  % parameters are [xi;eta]
        pwaObj = Opt(C, J, z, u);
        [pack.OPPWA, pack.pwaNr, pack.pwaStatus] = solve_pwa_with_timeout_(pwaObj, cfg);
    end

    % ------------------------------ OPNNProj (hard projection) ------------------------------
    ops_proj = sdpsettings('solver', cfg.solver, 'verbose', cfg.verbose);

    u_proj    = sdpvar(nu,1);
    uhat_proj = sdpvar(nu,1);
    xi_proj   = sdpvar(nxi,1);

    Cproj = (G*u_proj <= h - S*xi_proj);

    % Use squared 2-norm to keep it a QP (not SOCP)
    e = (u_proj - uhat_proj);
    Jproj = e'*e;

    pack.OPNNProj = optimizer(Cproj, Jproj, ops_proj, {xi_proj, uhat_proj}, u_proj);

    % ------------------------------ PureNN layers (optional) ------------------------------
    if cfg.buildPureNN
        pack.PureNNlayers = build_pureNN_(nxi + neta, nu, cfg.hiddenPureNN);
    end
end


% ================================= Helpers (local) =================================

function cfg = fill_cfg_(cfg)
    if ~isfield(cfg,'solver'),        cfg.solver = 'mosek'; end
    if ~isfield(cfg,'verbose'),       cfg.verbose = 0; end
    if ~isfield(cfg,'rho'),           cfg.rho = 1e2; end
    if ~isfield(cfg,'eps_s'),         cfg.eps_s = 1e1; end

    if ~isfield(cfg,'enablePWA'),     cfg.enablePWA = false; end
    if ~isfield(cfg,'pwaMaxTime_s'),  cfg.pwaMaxTime_s = 60; end
    if ~isfield(cfg,'pwaMaxRegions'), cfg.pwaMaxRegions = 3000; end

    if ~isfield(cfg,'buildPureNN'),   cfg.buildPureNN = true; end
    if ~isfield(cfg,'hiddenPureNN'),  cfg.hiddenPureNN = [64,64]; end
end

function [OPPWA, Nr, status] = solve_pwa_with_timeout_(pwaObj, cfg)
% Parfeval + timeout + region cap.

    fut = parfeval(@pwa_worker_solve_, 2, pwaObj);
    [OPPWA, Nr, status] = deal([], 0, 'timeout');

    t0 = tic;
    while toc(t0) < cfg.pwaMaxTime_s
        st = fut.State;
        if strcmp(st,'finished') || strcmp(st,'failed'), break; end
        pause(0.05);
    end

    st = fut.State;
    if strcmp(st,'finished')
        [OPPWA, Nr] = fetchOutputs(fut);
        if Nr > cfg.pwaMaxRegions
            [OPPWA, status] = deal([], 'too_many_regions');
        else
            status = 'ok';
        end
    elseif strcmp(st,'failed')
        status = 'failed';
    else
        cancel(fut);
    end
end


function [OPPWA, Nr] = pwa_worker_solve_(pwaObj)
    OPPWA = pwaObj.solve();
    Nr = numel(OPPWA.xopt.Set);
end
