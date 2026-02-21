function [w, info] = simplex_ls_(V, y, opts)
% simplex_ls_ //
% Solve: min_{w>=0, 1'w=1} ||V w - y||^2
% via projected gradient / FISTA on the simplex.
%
% Inputs:
%   V    : nu×K
%   y    : nu×1
%   opts : struct (optional)
%          .maxit     (default 200)
%          .resThr    (default 1e-8)    stop if ||Vw-y|| <= resThr
%          .tol_w     (default 1e-12)   stop if ||w-wprev|| small
%          .L         (default [])      Lipschitz const for grad; if empty, estimated
%          .init      (default 'nn')    'nn' nearest vertex, 'uni' uniform
%          .verbose   (default 0)
%
% Outputs:
%   w    : K×1, w>=0, sum(w)=1
%   info : (optional) struct with fields res, iters, res_hist, L

    if nargin < 3 || isempty(opts), opts = struct(); end
    maxit   = getfield_def_(opts,'maxit',  200);
    resThr  = getfield_def_(opts,'resThr', 1e-8);
    tol_w   = getfield_def_(opts,'tol_w',  1e-12);
    L       = getfield_def_(opts,'L',      []);
    init    = getfield_def_(opts,'init',   'nn');
    verbose = getfield_def_(opts,'verbose',0);

    V = double(V);
    y = double(y(:));

    [nu, K] = size(V);
    if K == 0 || numel(y) ~= nu
        w = [];
        if nargout > 1
            info = struct('res',inf,'iters',0,'res_hist',[],'L',[]);
        end
        return;
    end

    % ---- init w on simplex ----
    switch lower(char(init))
        case 'uni'
            w = ones(K,1)/K;
        otherwise % 'nn'
            vn2 = sum(V.^2, 1);          % 1×K
            ytV = (y.'*V);               % 1×K
            [~, j0] = min(vn2 - 2*ytV);
            w = zeros(K,1); w(j0)=1;
    end

    % ---- estimate Lipschitz constant L = 2*||V||_2^2 ----
    if isempty(L) || ~isfinite(L) || L <= 0
        % power iteration for spectral norm of V
        L = 2 * (specnorm_est_(V, 30)^2);
        if ~isfinite(L) || L <= 0
            % very safe fallback
            L = 2 * norm(V,'fro')^2;
        end
    end

    % ---- FISTA variables ----
    z = w;
    t = 1;

    res_hist = zeros(maxit,1);

    % precompute VVt multiply helper through V'*(V*x)
    Vt = V.'; % K×nu

    w_prev = w;
    for it = 1:maxit
        % gradient at z: grad = 2 V' (V z - y)
        rz   = V*z - y;                 % nu×1
        grad = 2*(Vt*rz);               % K×1

        % gradient step + projection
        w_new = proj_simplex_(z - (1/L)*grad);

        % evaluate residual
        r  = V*w_new - y;
        res = norm(r,2);
        res_hist(it) = res;

        % stopping
        if res <= resThr
            w = w_new;
            w_prev = w_new;
            break;
        end
        if norm(w_new - w_prev, 2) <= tol_w
            w = w_new;
            w_prev = w_new;
            break;
        end

        % FISTA momentum
        t_new = 0.5*(1 + sqrt(1 + 4*t^2));
        z = w_new + ((t - 1)/t_new)*(w_new - w_prev);

        w_prev = w_new;
        t = t_new;

        if verbose && (it==1 || mod(it,20)==0)
            fprintf('[simplex_ls_] it=%d res=%.3e L=%.3e\n', it, res, L);
        end
    end

    % finalize
    w = w_prev;
    w(w < 0) = 0;
    sw = sum(w);
    if sw > 0, w = w/sw; end

    if nargout > 1
        it_used = find(res_hist>0, 1, 'last');
        if isempty(it_used), it_used = 0; end
        info = struct();
        info.res      = norm(V*w - y, 2);
        info.iters    = it_used;
        info.res_hist = res_hist(1:max(it_used,1));
        info.L        = L;
    end
end

function sn = specnorm_est_(A, iters)
% estimate ||A||_2 by power iteration
    [m,n] = size(A);
    x = randn(n,1);
    x = x / norm(x,2);
    for k = 1:iters
        y = A*x;
        ny = norm(y,2);
        if ny == 0, sn = 0; return; end
        x = (A.'*y);
        nx = norm(x,2);
        if nx == 0, sn = 0; return; end
        x = x / nx;
    end
    sn = norm(A*x,2);
end
