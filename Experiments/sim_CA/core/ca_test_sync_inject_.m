function out = ca_test_sync_inject_(pack, Ustar, WDtest, opt)
% ========================================================================
% Closed-loop per method with synchronous injection + deadline
%
% Rule (synchronous injection):
%   At step k (sample at t_k), compute du_raw from (x_k, wd_k).
%   If compute time t_us(k) <= Ts_us: apply du_cmd = du_raw at t_{k+1}.
%   Else (timeout/miss): apply du_cmd = 0 (hold previous) at t_{k+1}.
%
% Methods (all run):
%   Opt, NN, NN+Proj, CertNet
%
% Oracle rerun (quality upper bound):
%   If a method's miss fraction > opt.miss_thr, rerun that method with NO deadline
%   (always apply du_raw). Store in out.oracle.<method>.
%
% Output:
%   out only stores raw time + run data; no aggregate metrics are computed here.
% ========================================================================
maxNumCompThreads(1);
%% (0) Options
if nargin < 4 || isempty(opt), opt = struct(); end
if ~isfield(opt,'Ts_us'), opt.Ts_us = pack.Ts_us; end
if ~isfield(opt,'miss_thr'), opt.miss_thr = 0.75; end
if ~isfield(opt,'clip_u'), opt.clip_u = true; end
if ~isfield(opt,'u_min'), opt.u_min = pack.u_min; end
if ~isfield(opt,'u_max'), opt.u_max = pack.u_max; end

[Ts_us, miss_thr, clip_u] = deal(opt.Ts_us, opt.miss_thr, opt.clip_u);
[u_min, u_max] = deal(opt.u_min, opt.u_max);

%% (1) Unpack
[OPbase, OPpureNNAlg, OPNNProj, OPCertNet] = deal(pack.OPbase, pack.OPpureNNAlg, pack.OPNNProj, pack.OPCertNet);
[B, G, S, h] = deal(pack.B, pack.G, pack.S, pack.h);

[nTest, nu] = deal(size(WDtest,1), size(Ustar,2));
nw = size(WDtest,2);

%% (2) Allocate output containers (deadline run)
names = {'Opt','NN','NNp','CN'};   % NNp = NN+Proj, CN = CertNet
out = struct();
out.meta = struct(); [out.meta.nTest,out.meta.nu,out.meta.nw,out.meta.Ts_us,out.meta.miss_thr] = deal(nTest,nu,nw,Ts_us,miss_thr);
out.ref = struct(); [out.ref.Ustar,out.ref.WDtest,out.ref.x0] = deal(Ustar,WDtest,Ustar(1,:).');

for j = 1:numel(names)
    nm = names{j};
    out.deadline.(nm) = struct();
    out.deadline.(nm).t_us    = zeros(nTest,1);
    out.deadline.(nm).miss    = false(nTest,1);
    out.deadline.(nm).du_raw  = zeros(nTest,nu);
    out.deadline.(nm).du_cmd  = zeros(nTest,nu);
    out.deadline.(nm).x       = zeros(nTest+1,nu);
    out.deadline.(nm).w       = zeros(nTest,nw);
    out.deadline.(nm).rhs_max = zeros(nTest,1);   % stores max residual of applied du (optional but "run data")
end

[out.deadline.Opt.x(1,:), out.deadline.NN.x(1,:), out.deadline.NNp.x(1,:), out.deadline.CN.x(1,:)] = deal(Ustar(1,:),Ustar(1,:),Ustar(1,:),Ustar(1,:));


%% (2.5) Warm-up (NOT timed)
% Use a representative sample (x0, wd0) to trigger JIT / solver init / cache warm.
xw  = Ustar(1,:).';
wdw = WDtest(1,:).';

nW_fast = 200;   % NN / CertNet

% Opt (teacher QP)
for i = 1:nW_fast
    OPbase{ xw, wdw };
    pure_nn_forward_alg_(OPpureNNAlg, [xw; wdw]);
    duhat = pure_nn_forward_alg_(OPpureNNAlg, [xw; wdw]);
    OPNNProj{ xw, duhat };
    OPCertNet.cert_forward([xw; wdw]);
end


%% (3) Deadline run: synchronous injection for all four methods
for k = 1:nTest
    wd = WDtest(k,:).';

    % ---------------- Opt ----------------
    x = out.deadline.Opt.x(k,:).';
    rhs = h - S*x;

    tt = tic;
    du = OPbase{ x, wd };
    out.deadline.Opt.t_us(k) = 1e6*toc(tt);
    du = double(du(:));

    out.deadline.Opt.du_raw(k,:) = du.';
    isMiss = (out.deadline.Opt.t_us(k) > Ts_us);
    out.deadline.Opt.miss(k) = isMiss;

    if isMiss, du_cmd = zeros(nu,1); else, du_cmd = du; end
    out.deadline.Opt.du_cmd(k,:) = du_cmd.';

    x_next = x + du_cmd;
    if clip_u, x_next = min(max(x_next, u_min), u_max); end
    out.deadline.Opt.x(k+1,:) = x_next.';

    out.deadline.Opt.w(k,:) = (B*x_next).';
    out.deadline.Opt.rhs_max(k) = max(G*du_cmd - rhs);

    % ---------------- NN ----------------
    x = out.deadline.NN.x(k,:).';
    rhs = h - S*x;

    tt = tic;
    du = pure_nn_forward_alg_(OPpureNNAlg, [x; wd]);
    out.deadline.NN.t_us(k) = 1e6*toc(tt);
    du = double(du(:));

    out.deadline.NN.du_raw(k,:) = du.';
    isMiss = (out.deadline.NN.t_us(k) > Ts_us);
    out.deadline.NN.miss(k) = isMiss;

    if isMiss, du_cmd = zeros(nu,1); else, du_cmd = du; end
    out.deadline.NN.du_cmd(k,:) = du_cmd.';

    x_next = x + du_cmd;
    if clip_u, x_next = min(max(x_next, u_min), u_max); end
    out.deadline.NN.x(k+1,:) = x_next.';

    out.deadline.NN.w(k,:) = (B*x_next).';
    out.deadline.NN.rhs_max(k) = max(G*du_cmd - rhs);

    % ---------------- NN + Proj ----------------
    x = out.deadline.NNp.x(k,:).';
    rhs = h - S*x;

    tt = tic;
    du_hat = pure_nn_forward_alg_(OPpureNNAlg, [x; wd]);   % independent du_hat (not shared with NN timing)
    du = OPNNProj{ x, du_hat };
    out.deadline.NNp.t_us(k) = 1e6*toc(tt);
    du = double(du(:));

    out.deadline.NNp.du_raw(k,:) = du.';
    isMiss = (out.deadline.NNp.t_us(k) > Ts_us);
    out.deadline.NNp.miss(k) = isMiss;

    if isMiss, du_cmd = zeros(nu,1); else, du_cmd = du; end
    out.deadline.NNp.du_cmd(k,:) = du_cmd.';

    x_next = x + du_cmd;
    if clip_u, x_next = min(max(x_next, u_min), u_max); end
    out.deadline.NNp.x(k+1,:) = x_next.';

    out.deadline.NNp.w(k,:) = (B*x_next).';
    out.deadline.NNp.rhs_max(k) = max(G*du_cmd - rhs);

    % ---------------- CertNet ----------------
    x = out.deadline.CN.x(k,:).';
    rhs = h - S*x;

    tt = tic;
    du = OPCertNet.cert_forward([x; wd]);
    out.deadline.CN.t_us(k) = 1e6*toc(tt);
    du = double(du(:));

    out.deadline.CN.du_raw(k,:) = du.';
    isMiss = (out.deadline.CN.t_us(k) > Ts_us);
    out.deadline.CN.miss(k) = isMiss;

    if isMiss, du_cmd = zeros(nu,1); else, du_cmd = du; end
    out.deadline.CN.du_cmd(k,:) = du_cmd.';

    x_next = x + du_cmd;
    if clip_u, x_next = min(max(x_next, u_min), u_max); end
    out.deadline.CN.x(k+1,:) = x_next.';

    out.deadline.CN.w(k,:) = (B*x_next).';
    out.deadline.CN.rhs_max(k) = max(G*du_cmd - rhs);
end

%% (4) Oracle rerun (quality upper bound) for methods with "mostly timeout"
out.oracle = struct(); out.oracle.rerun = struct(); [out.oracle.rerun.names,out.oracle.rerun.miss_frac] = deal({},[]);

for j = 1:numel(names)
    nm = names{j};
    miss_frac = mean(out.deadline.(nm).miss);
    if miss_frac <= miss_thr, continue; end

    out.oracle.rerun.names{end+1} = nm; %#ok<AGROW>
    out.oracle.rerun.miss_frac(end+1,1) = miss_frac; %#ok<AGROW>

    out.oracle.(nm) = struct();
    out.oracle.(nm).t_us   = zeros(nTest,1);    % still record compute time (no gating)
    out.oracle.(nm).du     = zeros(nTest,nu);
    out.oracle.(nm).x      = zeros(nTest+1,nu);
    out.oracle.(nm).w      = zeros(nTest,nw);
    out.oracle.(nm).rhs_max = zeros(nTest,1);

    out.oracle.(nm).x(1,:) = Ustar(1,:);

    for k = 1:nTest
        wd = WDtest(k,:).';
        x  = out.oracle.(nm).x(k,:).';
        rhs = h - S*x;

        if strcmp(nm,'Opt')
            tt = tic; du = OPbase{ x, wd }; out.oracle.(nm).t_us(k) = 1e6*toc(tt); du = double(du(:));
        elseif strcmp(nm,'NN')
            tt = tic; du = pure_nn_forward_alg_(OPpureNNAlg, [x; wd]); out.oracle.(nm).t_us(k) = 1e6*toc(tt); du = double(du(:));
        elseif strcmp(nm,'NNp')
            tt = tic; du_hat = pure_nn_forward_alg_(OPpureNNAlg, [x; wd]); du = OPNNProj{ x, du_hat }; out.oracle.(nm).t_us(k) = 1e6*toc(tt); du = double(du(:));
        elseif strcmp(nm,'CN')
            tt = tic; du = OPCertNet.cert_forward([x; wd]); out.oracle.(nm).t_us(k) = 1e6*toc(tt); du = double(du(:));
        end

        out.oracle.(nm).du(k,:) = du.';

        x_next = x + du;                 % NO deadline gating here
        if clip_u, x_next = min(max(x_next, u_min), u_max); end
        out.oracle.(nm).x(k+1,:) = x_next.';

        out.oracle.(nm).w(k,:) = (B*x_next).';
        out.oracle.(nm).rhs_max(k) = max(G*du - rhs);
    end
end
end
