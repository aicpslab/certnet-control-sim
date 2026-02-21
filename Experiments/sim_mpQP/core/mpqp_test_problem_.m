function out = mpqp_test_problem_(Prob, ops, OPpureNNAlg, OPCertNet, XTest, cfg)
% mpqp_test_problem_
% Single-problem benchmark (no plots). Supports eta: x=[xi;eta].
%
% IMPORTANT:
%   - This function does NOT generate XTest internally.
%   - You should generate XTest by mpqp_gen_trainingData(...) and pass it in.
%   - No rng(...) inside.
%
% Inputs:
%   Prob: .nu,.nxi,.neta and hard interface .G,.S,.h
%   ops:
%     .OPbase   : optimizer({xi,eta})->u
%     .OPNNProj : optimizer({xi,uhat})->u_proj
%     .OPPWA (optional), .pwaStatus
%   OPpureNNAlg: pure NN forward struct
%   OPCertNet: Certnet object with cert_forward(x), cert.vertices(x) (optional)
%   XTest: N×(nxi+neta), rows [xi, eta]
%   cfg (optional):
%     .warmN        (default 200)
%     .tol_viol     (default 1e-7)
%     .store_arrays (default true)
%     .XTrainAct    (optional) for PWA Act-cache
%     .optPWA       (optional) passed to pwa_eval_u_

    maxNumCompThreads(1);

    if nargin < 6, cfg = struct(); end
    if ~isfield(cfg,'warmN'), cfg.warmN = 200; end
    if ~isfield(cfg,'tol_viol'), cfg.tol_viol = 1e-6; end
    if ~isfield(cfg,'store_arrays'), cfg.store_arrays = true; end
    if isfield(cfg,'XTrainAct'), XTrainAct = cfg.XTrainAct; else, XTrainAct = []; end
    if isfield(cfg,'optPWA'), optPWA = cfg.optPWA; else, optPWA = struct(); end

    nu   = Prob.nu;
    nxi  = Prob.nxi;
    neta = Prob.neta;

    G = Prob.G; S = Prob.S; h = Prob.h;

    nTest = size(XTest,1);

    % ---- localize ops fields (avoid repeated struct access)
    OPbase  = ops.OPbase;
    OPNNProj = ops.OPNNProj;

    % ---- determine if PWA is available
    usePWA = false;
    if isfield(ops,'OPPWA') && ~isempty(ops.OPPWA) && isfield(ops,'pwaStatus')
        try
            usePWA = (string(ops.pwaStatus) == "ok");
        catch
            usePWA = strcmpi(char(ops.pwaStatus), 'ok');
        end
    end
    OPPWA = [];
    if usePWA, OPPWA = ops.OPPWA; end

    % ---- precompute hard RHS for violations
    XiTest = XTest(:, 1:nxi);
    rhsH = (h - S * XiTest.');     % mH × nTest

    % ---- warm-up (in-function, NOT timed)
    warmN = min(cfg.warmN, nTest);
    if warmN > 0
        for ii = 1:warmN
            xi  = XTest(ii, 1:nxi).';
            eta = XTest(ii, nxi+1:nxi+neta).';
            x   = XTest(ii,:).';

            u_qp = OPbase{xi, eta}; %#ok<NASGU>

            if usePWA
                u_pwa = pwa_eval_u_(OPPWA, x, XTrainAct, optPWA); %#ok<NASGU>
            end

            u_nn = pure_nn_forward_alg_(OPpureNNAlg, single(x)); %#ok<NASGU>

            u_pr = OPNNProj{xi, u_nn}; %#ok<NASGU>

            if ~isempty(OPCertNet)
                u_cn = OPCertNet.cert_forward(x); %#ok<NASGU>
                Vtmp = OPCertNet.cert.vertices(x); %#ok<NASGU>
            end
        end
    end

    % ---- allocate
    t_qp_us  = nan(nTest,1);
    t_nn_us  = nan(nTest,1);
    t_prj_us = nan(nTest,1);
    t_cn_us  = nan(nTest,1);
    t_pwa_us = nan(nTest,1);

    K_cn = nan(nTest,1);

    if cfg.store_arrays
        mse_nn  = nan(nTest,1);
        mse_prj = nan(nTest,1);
        mse_cn  = nan(nTest,1);
        mse_pwa = nan(nTest,1);

        v_qp  = nan(nTest,1);
        v_nn  = nan(nTest,1);
        v_prj = nan(nTest,1);
        v_cn  = nan(nTest,1);
        v_pwa = nan(nTest,1);
    else
        mse_nn=[]; mse_prj=[]; mse_cn=[]; mse_pwa=[];
        v_qp=[]; v_nn=[]; v_prj=[]; v_cn=[]; v_pwa=[];
    end

    fail = struct('qp',0,'pwa',0,'nn',0,'prj',0,'cn',0);

    % ---- main loop
    for i = 1:nTest
        xi  = XTest(i, 1:nxi).';
        eta = XTest(i, nxi+1:nxi+neta).';
        x   = XTest(i,:).';
        rhs_i = rhsH(:,i);

        % ---------- QP teacher ----------
        tt = tic;
        u_qp = OPbase{xi, eta};
        t_qp_us(i) = 1e6*toc(tt);
        u_qp = double(u_qp(:));
        if ~u_ok_(u_qp, nu)
            u_qp = nan(nu,1);
            fail.qp = fail.qp + 1;
        end

        % ---------- PWA (optional) ----------
        if usePWA
            tt = tic;
            u_pwa = pwa_eval_u_(OPPWA, x, XTrainAct, optPWA);
            if isnan(u_pwa)
                ttt=1;
            end
            t_pwa_us(i) = 1e6*toc(tt);
            u_pwa = double(u_pwa(:));
            if ~u_ok_(u_pwa, nu)
                u_pwa = nan(nu,1);
                fail.pwa = fail.pwa + 1;
            end
        else
            u_pwa = nan(nu,1);
            t_pwa_us(i) = nan;
        end

        % ---------- PureNN (ALG) ----------
        tt = tic;
        u_nn = pure_nn_forward_alg_(OPpureNNAlg, single(x));
        t_nn_us(i) = 1e6*toc(tt);
        u_nn = double(u_nn(:));
        if ~u_ok_(u_nn, nu)
            u_nn = nan(nu,1);
            fail.nn = fail.nn + 1;
        end

        % ---------- NN + projection ----------
        tt = tic;
        if all(isfinite(u_nn))
            u_pr = OPNNProj{xi, u_nn};
            u_pr = double(u_pr(:));
        else
            u_pr = nan(nu,1);
        end
        t_prj_us(i) = 1e6*toc(tt);
        if ~u_ok_(u_pr, nu)
            u_pr = nan(nu,1);
            fail.prj = fail.prj + 1;
        end

        % ---------- CertNet ----------
        if ~isempty(OPCertNet)
            tt = tic;
            u_cn = OPCertNet.cert_forward(x);
            t_cn_us(i) = 1e6*toc(tt);
            u_cn = double(u_cn(:));
            if ~u_ok_(u_cn, nu)
                u_cn = nan(nu,1);
                fail.cn = fail.cn + 1;
            end

            % Candidate count K (not timed)
            Vtmp = OPCertNet.cert.vertices(x);
            K_cn(i) = size(Vtmp,1);
        else
            u_cn = nan(nu,1);
            t_cn_us(i) = nan;
            K_cn(i) = nan;
        end

        % ---------- metrics ----------
        if cfg.store_arrays
            v_qp(i)  = viol_(G, u_qp,  rhs_i);
            v_pwa(i) = viol_(G, u_pwa, rhs_i);
            v_nn(i)  = viol_(G, u_nn,  rhs_i);
            v_prj(i) = viol_(G, u_pr,  rhs_i);
            v_cn(i)  = viol_(G, u_cn,  rhs_i);

            if all(isfinite(u_qp))
                mse_pwa(i) = mse_(u_pwa, u_qp);
                mse_nn(i)  = mse_(u_nn,  u_qp);
                mse_prj(i) = mse_(u_pr,  u_qp);
                mse_cn(i)  = mse_(u_cn,  u_qp);
            end
        end
    end

    % ---- pack outputs
    out = struct();
    out.XTest = XTest;

    out.timing_us = struct('qp',t_qp_us,'pwa',t_pwa_us,'nn',t_nn_us,'prj',t_prj_us,'cn',t_cn_us);
    out.K = struct('cn', K_cn);

    if cfg.store_arrays
        out.mse  = struct('pwa',mse_pwa,'nn',mse_nn,'prj',mse_prj,'cn',mse_cn);
        out.viol = struct('qp',v_qp,'pwa',v_pwa,'nn',v_nn,'prj',v_prj,'cn',v_cn);
    end

    out.failCounts = fail;
    out.summary = mpqp_summarize_(out, cfg.tol_viol, usePWA, ops);
end

% ====================== local helpers ======================
function ok = u_ok_(u, nu)
    ok = (numel(u) == nu) && all(isfinite(u));
end

function v = viol_(G, u, rhs)
    if any(~isfinite(u)), v = inf; return; end
    v = max(G*u - rhs);
end

function e = mse_(u, uref)
    if any(~isfinite(u)) || any(~isfinite(uref)), e = nan; return; end
    e = mean((u-uref).^2);
end

function S = mpqp_summarize_(out, tol_viol, usePWA, ops)
    qtim = @(t) struct('mean',mean(t,'omitnan'), 'p50',prctile(t,50), 'p99',prctile(t,99), 'max',max(t,[],'omitnan'));

    S = struct();
    S.timing = struct();
    S.timing.qp  = qtim(out.timing_us.qp);
    S.timing.nn  = qtim(out.timing_us.nn);
    S.timing.prj = qtim(out.timing_us.prj);
    S.timing.cn  = qtim(out.timing_us.cn);

    if usePWA
        S.timing.pwa = qtim(out.timing_us.pwa);
    else
        S.timing.pwa = [];
    end

    if isfield(out,'mse')
        S.mse = struct();
        if usePWA, S.mse.pwa = stats_vec_(out.mse.pwa); else, S.mse.pwa = []; end
        S.mse.nn  = stats_vec_(out.mse.nn);
        S.mse.prj = stats_vec_(out.mse.prj);
        S.mse.cn  = stats_vec_(out.mse.cn);
    end

    if isfield(out,'viol')
        S.viol = struct();
        S.viol.tol = tol_viol;
        S.viol.qp  = viol_stats_(out.viol.qp,  tol_viol);
        if usePWA, S.viol.pwa = viol_stats_(out.viol.pwa, tol_viol); else, S.viol.pwa = []; end
        S.viol.nn  = viol_stats_(out.viol.nn,  tol_viol);
        S.viol.prj = viol_stats_(out.viol.prj, tol_viol);
        S.viol.cn  = viol_stats_(out.viol.cn,  tol_viol);
    end

    S.failCounts = out.failCounts;

    if usePWA
        if isfield(ops,'pwaNr'), S.pwaNr = ops.pwaNr; else, S.pwaNr = nan; end
        if isfield(ops,'pwaStatus'), S.pwaStatus = string(ops.pwaStatus); else, S.pwaStatus = "ok"; end
    else
        if isfield(ops,'pwaNr'), S.pwaNr = ops.pwaNr; else, S.pwaNr = nan; end
        if isfield(ops,'pwaStatus'), S.pwaStatus = string(ops.pwaStatus); else, S.pwaStatus = "skip"; end
    end
end

function st = stats_vec_(x)
    st = struct();
    st.mean = mean(x,'omitnan');
    st.p95  = prctile(x,95);
    st.max  = max(x,[],'omitnan');
end

function st = viol_stats_(v, tol)
    st = struct();
    st.max  = max(v,[],'omitnan');
    st.rate = mean(v > tol);
end

function u = pwa_eval_u_(OPPWA, x, XTrain, opt)
% pwa_eval_u_ //
% Dual-cache evaluator for MPT3 PolyUnion explicit solution.
% Cache layout matches:
%   cache = struct('Aall','ball','row2pos','idList','M2','uball')
% Query logic matches query_(cache,x,opt): mark violated rows -> bad regions -> posOK=find(~bad).
% Returns ONLY ONE u (the first feasible region in cache order).
%
% Act-cache:
%   - If XTrain is provided once (non-empty), build ACT cache from FULL.
%   - Later calls can omit XTrain; ACT cache will still be used (persistent).

    if nargin < 3, XTrain = []; end
    if nargin < 4, opt = struct(); end

    x = x(:);

    persistent fullCache actCache actMeta

    % ---- (0) build/refresh FULL cache ----
    if isempty(fullCache) || ~cache_is_compatible_full_(fullCache, OPPWA.xopt)
        fullCache = pwa_cache_build_full_(OPPWA.xopt, opt);
        actCache  = [];
        actMeta   = struct();
    end

    % ---- (1) build/refresh ACT cache if XTrain provided ----
    if ~isempty(XTrain)
        needRebuild = true;

        if isstruct(actMeta) && isfield(actMeta,'fullSig') && isfield(actMeta,'Ntrain') && isfield(actMeta,'Dim')
            if all(actMeta.fullSig == cache_sig_(fullCache)) && actMeta.Ntrain == size(XTrain,1) && actMeta.Dim == size(XTrain,2)
                needRebuild = false;
            end
        end

        if needRebuild
            posAct  = pwa_collect_posAct_from_Xtrain_(fullCache, XTrain, opt);
            actCache = pwa_cache_build_act_from_full_(fullCache, posAct);

            actMeta = struct();
            actMeta.fullSig = cache_sig_(fullCache);
            actMeta.Ntrain  = size(XTrain,1);
            actMeta.Dim     = size(XTrain,2);
            actMeta.posAct  = posAct;

            fprintf('PWA actCache regions: %d\n', numel(posAct));

        end
    end

    % ---- (2) query order ----
    act_first = getfield_def_(opt,'act_first', true);

    useAct = ~isempty(actCache);   % IMPORTANT: even if XTrain omitted now, still use existing actCache

    if useAct && act_first
        [ok,u] = pwa_eval_one_querylike_(actCache, x, opt);
        if ok, return; end
        [ok,u] = pwa_eval_one_querylike_(fullCache, x, opt);
        if ok, return; end
    else
        [ok,u] = pwa_eval_one_querylike_(fullCache, x, opt);
        if ok, return; end
        if useAct
            [ok,u] = pwa_eval_one_querylike_(actCache, x, opt);
            if ok, return; end
        end
    end

    % ---- (3) rare fallback ----
    u = OPPWA.xopt.feval(x,'primal');
end


% =====================================================================
%                          CORE EVAL (query_-style)
% =====================================================================

function [ok, u] = pwa_eval_one_querylike_(cache, xq, opt)
% Query logic matches:
%   y=Aall*x; viol=(y-ball>tol); bad(row2pos(viol))=true; posOK=find(~bad)
% but returns only ONE u: pos=posOK(1).

    if nargin < 3, opt = struct(); end
    tol = getfield_def_(opt,'tol_query',1e-9);

    xq = xq(:);

    nReg = numel(cache.idList);
    if nReg == 0
        ok = false; u = [];
        return
    end

    y    = cache.Aall * xq;
    viol = (y - cache.ball > tol);

    bad = false(nReg,1);
    if any(viol)
        bad(cache.row2pos(viol)) = true;
    end

    posOK = find(~bad);
    if isempty(posOK)
        ok = false; u = [];
        return
    end

    pos = posOK(1);

    nu = size(cache.uball,2);
    rows = (pos-1)*nu + (1:nu);

    tmp = cache.M2(rows,:) * xq;
    u   = tmp + cache.uball(pos,:).';

    ok = true;
end


% =====================================================================
%                              CACHE BUILDERS
% =====================================================================

function cache = pwa_cache_build_full_(PU, opt)
% Build FULL cache with fields exactly like cache_init_(nx,nu):
%   Aall, ball, row2pos, idList, M2, uball
% such that:
%   - row2pos maps each inequality row in Aall to region position (1..nReg)
%   - M2/uball are stacked by region blocks: rows ((pos-1)*nu+(1:nu)) correspond to region pos

    if nargin < 2, opt = struct(); end
    tol_query = getfield_def_(opt,'tol_query',1e-9); %#ok<NASGU>

    Sets0 = PU.Set;
    Nr0   = numel(Sets0);
    Dim   = PU.Dim;

    A = {}; b = {};
    F = {}; g = {};
    idList = [];

    kept = 0;
    mTot = 0;
    nu   = 0;

    for i0 = 1:Nr0
        P = Sets0(i0);

        if poly_is_empty_(P)
            continue
        end

        % inequalities
        try
            Ai = P.A; bi = P.b;
        catch
            continue
        end
        if isempty(Ai) || isempty(bi) || size(Ai,2) ~= Dim
            continue
        end

        % affine primal law
        try
            Aff = P.getFunction('primal');
            Fi  = Aff.F;
            gi  = Aff.g;
        catch
            continue
        end
        if isempty(Fi) || size(Fi,2) ~= Dim || isempty(gi)
            continue
        end
        if kept == 0
            nu = size(Fi,1);
        else
            if size(Fi,1) ~= nu
                continue
            end
        end

        kept = kept + 1;
        A{kept,1} = Ai;
        b{kept,1} = bi;
        F{kept,1} = Fi;
        g{kept,1} = gi(:);
        idList(kept,1) = i0; %#ok<AGROW>

        mTot = mTot + size(Ai,1);
    end

    if kept == 0
        error('pwa_cache_build_full_: no valid (non-empty) regions found.');
    end

    cache = cache_init_(Dim, nu);
    cache.idList = double(idList);

    cache.Aall    = zeros(mTot, Dim);
    cache.ball    = zeros(mTot, 1);
    cache.row2pos = zeros(mTot, 1, 'uint32');

    cache.M2    = zeros(nu*kept, Dim);
    cache.uball = zeros(kept, nu);

    % ---- stack inequalities + row2pos ----
    r = 1;
    for pos = 1:kept
        Ai = A{pos}; bi = b{pos};
        mi = size(Ai,1);
        idx = r:(r+mi-1);

        cache.Aall(idx,:)    = Ai;
        cache.ball(idx)      = bi;
        cache.row2pos(idx,1) = uint32(pos);

        r = r + mi;
    end

    % ---- stack affine laws into M2/uball ----
    for pos = 1:kept
        rows = (pos-1)*nu + (1:nu);
        cache.M2(rows,:)     = F{pos};
        cache.uball(pos,:)   = g{pos}(:).';
    end
end


function act = pwa_cache_build_act_from_full_(full, posAct)
% Build ACT cache from FULL cache using region positions in FULL (1..nRegFull).
% Output cache has the same 6 fields layout.

    posAct = unique(posAct(:));
    nRegFull = numel(full.idList);
    posAct = posAct(posAct>=1 & posAct<=nRegFull);

    if isempty(posAct)
        act = [];
        return
    end

    Dim = size(full.Aall,2);
    nu  = size(full.uball,2);

    actNr = numel(posAct);
    act = cache_init_(Dim, nu);

    % region ids
    act.idList = full.idList(posAct);

    % affine blocks
    act.M2    = zeros(nu*actNr, Dim);
    act.uball = full.uball(posAct,:);

    for k = 1:actNr
        oldPos = posAct(k);
        rows_old = (oldPos-1)*nu + (1:nu);
        rows_new = (k-1)*nu + (1:nu);
        act.M2(rows_new,:) = full.M2(rows_old,:);
    end

    % inequalities: select rows whose row2pos in posAct, then remap row2pos -> 1..actNr
    posAct_u = uint32(posAct(:));
    keepRow = false(size(full.row2pos));

    for k = 1:numel(posAct_u)
        keepRow = keepRow | (full.row2pos == posAct_u(k));
    end

    act.Aall = full.Aall(keepRow,:);
    act.ball = full.ball(keepRow);

    oldRow2 = full.row2pos(keepRow);   % uint32 in [1..nRegFull]

    map_old2new = zeros(nRegFull,1,'uint32');
    for k = 1:actNr
        map_old2new(posAct(k)) = uint32(k);
    end

    act.row2pos = map_old2new(double(oldRow2));
end


% =====================================================================
%                 OFFLINE: COLLECT ACTIVE POS FROM XTRAIN
% =====================================================================

function posAct = pwa_collect_posAct_from_Xtrain_(fullCache, Xtrain, opt)
% Collect active region POSITIONS (w.r.t FULL cache ordering 1..nRegFull)
% by query_-style marking and picking posOK(1) for each sample.

    if nargin < 3, opt = struct(); end
    tol = getfield_def_(opt,'tol_query',1e-9);

    Dim = size(fullCache.Aall,2);
    if size(Xtrain,2) ~= Dim
        error('pwa_collect_posAct_from_Xtrain_: Xtrain must have Dim=%d columns.', Dim);
    end

    N = size(Xtrain,1);
    nReg = numel(fullCache.idList);

    posHit = zeros(N,1,'uint32');

    for i = 1:N
        x = Xtrain(i,:).';
        y    = fullCache.Aall * x;
        viol = (y - fullCache.ball > tol);

        bad = false(nReg,1);
        if any(viol)
            bad(fullCache.row2pos(viol)) = true;
        end

        posOK = find(~bad);
        if ~isempty(posOK)
            posHit(i) = uint32(posOK(1));
        end
    end

    posAct = double(unique(posHit(posHit>0)));
end


% =====================================================================
%                               HELPERS
% =====================================================================

function ok = cache_is_compatible_full_(cache, PU)
% Minimal compatibility check:
% - dimension must match
% (If you reuse this function across different problems with same Dim, consider clearing functions or clearing persistent.)

    ok = true;
    try
        if isempty(cache) || ~isstruct(cache)
            ok = false; return
        end
        if size(cache.Aall,2) ~= PU.Dim
            ok = false; return
        end
        if size(cache.M2,2) ~= PU.Dim
            ok = false; return
        end
    catch
        ok = false;
    end
end


function sig = cache_sig_(cache)
% Signature derived ONLY from the 6 core fields.
    Dim  = size(cache.Aall,2);
    nReg = numel(cache.idList);
    mTot = size(cache.Aall,1);
    nu   = size(cache.uball,2);
    sig = [Dim; nReg; mTot; nu];
end


function cache = cache_init_(nx, nu)
% cache_init_ (exactly your layout)
    if nargin < 1 || isempty(nx), nx = 0; end
    nx = double(nx);

    cache = struct( ...
        'Aall',    zeros(0, nx), ...
        'ball',    zeros(0, 1),  ...
        'row2pos', zeros(0, 1),  ...
        'idList',  zeros(0, 1),  ...
        'M2',      zeros(0, nx), ...
        'uball',   zeros(0, nu));
end


function tf = poly_is_empty_(P)
% Robust empty check for MPT3 Polyhedron
    tf = false;

    try
        if isprop(P,'isEmptySet') && P.isEmptySet, tf = true; return; end
    catch
    end
    try
        if ismethod(P,'isEmptySet') && P.isEmptySet(), tf = true; return; end
    catch
    end
    try
        if ismethod(P,'isEmpty') && P.isEmpty(), tf = true; return; end
    catch
    end

    try
        if isempty(P.A) || isempty(P.b), tf = true; return; end
    catch
    end
end