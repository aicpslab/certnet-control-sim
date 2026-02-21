function [supp, wS] = carath_reduce_(V, w, epsw)
% carath_reduce_ //
% Numerically-stable Carathéodory reduction on simplex weights.
% Tries to preserve V*w (up to roundoff) while reducing support to <= nu+1.

    if nargin < 3 || isempty(epsw), epsw = 1e-12; end

    V = double(V);
    w = double(w(:));
    [nu,K] = size(V);
    if numel(w) ~= K
        error('carath_reduce_: V must be nu×K and w must be K×1.');
    end

    % light sanitize to simplex
    w(w<0) = 0;
    sw = sum(w);
    if sw <= 0, supp=[]; wS=[]; return; end
    w = w/sw;

    supp = find(w > epsw);

    while numel(supp) > (nu+1)
        ws = w(supp);
        Vs = V(:,supp);
        m  = numel(supp);

        A = [Vs; ones(1,m)];   % (nu+1)×m

        % ---- get a nullspace direction alpha ----
        Z = null(A,'r');       % m×d, robust rank-revealing
        if isempty(Z)
            % fallback: SVD basis for smallest singular directions
            [~,~,Vsvd] = svd(A,'econ');
            Z = Vsvd(:,end);   % m×1
        end

        alpha = [];
        for trial = 1:10
            if size(Z,2) == 1
                a = Z;
            else
                a = Z * randn(size(Z,2),1);
            end

            % project back to nullspace to reduce drift: a <- a - A'*(AA')^+*(A a)
            a = proj_to_null_(A, a);

            % need mixed signs
            ip = find(a > 0);
            in = find(a < 0);
            if ~isempty(ip) && ~isempty(in)
                alpha = a;
                break;
            end
        end
        if isempty(alpha)
            break; % cannot find usable direction
        end

        % ---- step to hit one zero (keep nonnegativity) ----
        ip = find(alpha > 0);
        t  = min(ws(ip) ./ alpha(ip));     % ensures ws_new(ip) >= 0 and at least one hits 0

        ws_new = ws - t*alpha;

        % tiny numeric cleanup only
        ws_new(abs(ws_new) < 10*epsw) = 0;
        ws_new(ws_new < 0 & abs(ws_new) < 10*epsw) = 0;

        % write back (no hard clipping)
        w(:) = 0;
        w(supp) = ws_new;

        % gentle renorm (sum should already be ~1)
        sw = sum(w);
        if sw <= 0, break; end
        w = w/sw;

        supp = find(w > epsw);
    end

    wS = w(supp);
    sw = sum(wS);
    if sw > 0, wS = wS/sw; end
end

function a = proj_to_null_(A, a)
% Orthogonal projection of a onto null(A) using a <- a - A'*(AA')^+*(A a)

    Aa = A*a;
    G  = A*A.';                       % (nu+1)×(nu+1)
    % use pinv for safety (handles rank deficiency)
    a  = a - A.'*(pinv(G)*Aa);

    % one more refinement (optional but helps)
    Aa = A*a;
    a  = a - A.'*(pinv(G)*Aa);
end
