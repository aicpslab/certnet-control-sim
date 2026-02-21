function [ok, info] = convex_rep_ok_(U, u, cfg)
% convex_rep_ok_ //
% No-solver convex combination feasibility check for u in conv(rows(U)).
% Strategy:
%   (1) quick row-hit
%   (2) greedy active-set + simplex_ls_ (fast, may false-negative)
%   (3) fallback: small pool (nearest points) + enumerate subsets of size (nu+1)
%       and solve affine weights by linear system, check w>=0 and residual.
%
% Inputs:
%   U   : K×nu
%   u   : nu×1 (or 1×nu)
%   cfg : optional
%     .resThr     (default 1e-6)   accept if residual_inf <= resThr
%     .epsw       (default 1e-12)  weight threshold for support
%     .maxOuter   (default nu+3)   greedy iterations
%     .ls_maxit   (default 50)     simplex_ls_ maxit
%     .ls_resThr  (default 1e-10)  simplex_ls_ residual stop
%     .poolM      (default min(25,K))  pool size for enumeration
%     .enumCap    (default 6000)   max number of subsets to test
%
% Outputs:
%   ok, info (status, resInf, idx, w, note)
    use_LP =getfield_def_(cfg,'use_LP',  0);


    if nargin < 3, cfg = struct(); end
    resThr   = getfield_def_(cfg,'resThr',  1e-6);
    epsw     = getfield_def_(cfg,'epsw',    1e-12);
    ls_maxit = getfield_def_(cfg,'ls_maxit',50);
    ls_resThr= getfield_def_(cfg,'ls_resThr',1e-10);

    U = double(U);
    u = double(u(:));          % force column
    [K,nu] = size(U);

    if use_LP
        opts =sdpsettings('solver','mosek','verbose',0);
        lambda=sdpvar(K,1);
        cons = [U'*lambda==u,sum(lambda)==1,lambda(:)>=0];
        
        info =optimize(cons,[],opts);

        ok =~info.problem;
    else
            maxOuter = getfield_def_(cfg,'maxOuter', nu+3);
    poolM    = getfield_def_(cfg,'poolM',    min(25,K));
    enumCap  = getfield_def_(cfg,'enumCap',  6000);

    info = struct('status','', 'resInf',Inf, 'idx',int32([]), 'w',[], 'note','');

    if K==0 || numel(u)~=nu
        ok=false; info.status='EMPTY_OR_DIM_MISMATCH'; return;
    end

    % ---- (1) quick row-hit in inf-norm ----
    dInf = max(abs(U - u.'), [], 2);
    [dmin, jhit] = min(dInf);
    if dmin <= resThr
        ok = true;
        info.status = 'ROW_HIT';
        info.resInf = dmin;
        info.idx    = int32(jhit);
        info.w      = 1;
        return;
    end

    % ---- (2) greedy active-set + simplex LS (fast) ----
    ok = false;
    [okG, infoG] = greedy_check_(U, u, nu, resThr, epsw, maxOuter, ls_maxit, ls_resThr);
    if okG
        ok = true;
        info = infoG;
        info.status = 'GREEDY_OK';
        return;
    end

    % ---- (3) fallback: pool + enumerate subsets of size (nu+1) ----
    % Build small pool of closest candidates (L2)
    du2 = sum((U - u.').^2, 2);
    [~, ord] = sort(du2, 'ascend');
    ord = ord(1:poolM);

    m = min(nu+1, numel(ord));
    if m <= 1
        ok=false; info=infoG; info.status='FAIL'; info.note='POOL_TOO_SMALL'; return;
    end

    % Enumerate combinations from the pool (cap for safety)
    comb = nchoosek(1:numel(ord), m);
    if size(comb,1) > enumCap
        comb = comb(1:enumCap,:); % deterministic cap
    end

    bestRes = Inf; bestIdx=[]; bestW=[];

    for t = 1:size(comb,1)
        idxLocal = ord(comb(t,:));
        V = U(idxLocal,:).';                  % nu×m
        A = [V; ones(1,m)];
        b = [u; 1];

        % Solve affine weights (least-norm if singular)
        if rcond(A*A.') < 1e-14
            w = pinv(A)*b;
        else
            w = A\b;
        end

        % Check simplex and residual
        if any(~isfinite(w)), continue; end
        if min(w) < -1e-10, continue; end     % allow tiny negatives
        w(w<0) = 0;
        sw = sum(w);
        if sw <= 0, continue; end
        w = w/sw;

        uhat = V*w;
        rInf = max(abs(uhat - u));
        if rInf < bestRes
            bestRes = rInf;
            bestIdx = idxLocal;
            bestW   = w;
            if rInf <= resThr
                ok = true;
                info.status = 'ENUM_OK';
                info.resInf = rInf;
                info.idx    = int32(bestIdx(:));
                info.w      = bestW(:);
                info.note   = 'FOUND_SUBSET';
                return;
            end
        end
    end

    % If not OK, return best found (useful for debugging threshold)
    info = infoG;
    info.status = 'FAIL';
    info.note   = 'GREEDY_FAIL_ENUM_FAIL';
    info.resInf = bestRes;
    info.idx    = int32(bestIdx(:));
    info.w      = bestW(:);
    end
end

% ---------------- helpers ----------------

function [ok, info] = greedy_check_(U, u, nu, resThr, epsw, maxOuter, ls_maxit, ls_resThr)
    [K,~] = size(U);
    info = struct('resInf',Inf,'idx',int32([]),'w',[]);

    % init nearest vertex (L2)
    vn2 = sum(U.^2,2);
    [~, j0] = min(vn2 - 2*(U*u));
    S = int32(j0);
    wS = 1;

    ok = false;
    for it = 1:maxOuter
        V    = U(double(S), :).';           % nu×m
        uhat = V*double(wS(:));
        r    = u - uhat;
        rInf = max(abs(r));

        info.resInf = rInf;
        info.idx    = int32(S);
        info.w      = double(wS(:));

        if rInf <= resThr
            ok = true; return;
        end

        % add point maximizing alignment with residual
        scores = (U - uhat.') * r;
        scores(double(S)) = -Inf;
        [~, jadd] = max(scores);
        if ~isfinite(scores(jadd)), return; end
        S = unique([S; int32(jadd)], 'stable');

        % solve simplex LS on current support
        V = U(double(S), :).';
        optsLS = struct('maxit', ls_maxit, 'resThr', ls_resThr, 'tol_w', 1e-12, 'init', 'nn', 'verbose', 0);
        [wS, ~] = simplex_ls_(V, u, optsLS);

        % reduce support to <= nu+1
        if numel(S) > (nu+1)
            [supp, wred] = carath_reduce_(V, wS, epsw);
            if ~isempty(supp)
                S  = S(int32(supp(:)));
                wS = wred(:);
            end
        end

        wS(wS<0)=0;
        sw = sum(wS);
        if sw<=0, return; end
        wS = wS/sw;
    end
end

function v = getfield_def_(s, name, def)
    if isstruct(s) && isfield(s,name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = def;
    end
end
