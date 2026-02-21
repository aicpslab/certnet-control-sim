function Prob = mpqp_make_problem_(nu, nxi, mCutsTotal, seed, cfg)
% make_qp_problem_
% ONE random QP-with-hard/soft polyhedral constraints.
%
% Decision variable: u in R^{nu}
% Parameter:         xi in R^{nxi}
% Extra variable:    eta in R^{neta} (NOT counted in nxi)
%
% IMPORTANT: internal stacked variable is z = [xi; u]  (xi first, u last)
%
% Hard:   G u <= h - S xi
% Soft:   Gs u <= hs - Ss xi - Ts eta + s,  s >= 0
%
% Cost:
%   0.5*u'*H*u + (F*xi + Feta*eta + f)'*u + rho*sum(s) + eps_s*(s'*s)

    if nargin < 5, cfg = struct(); end
    if ~isfield(cfg,'Lcube'),       cfg.Lcube = 1; end
    if ~isfield(cfg,'ensure_full'), cfg.ensure_full = true; end
    if ~isfield(cfg,'neta'),        cfg.neta = 1; end

    neta = cfg.neta;

    rng(seed);

    d = nxi + nu;  % z = [xi; u]

    % Build a random polytope inside cube in z=[xi;u] space.
    Pfull = make_rand_poly_in_cube_(d, cfg.Lcube, mCutsTotal, cfg);
    Pfull.normalize;
    Pfull = Pfull.minHRep;

    % Post-hoc split AFTER minHRep
    mEff  = size(Pfull.A, 1);
    mS = floor(4*mEff/5);

    if cfg.ensure_full
        assert(mEff >= 2, 'Too few inequalities after minHRep (mEff=%d). Increase mCutsTotal.', mEff);
    end

    Ps = Polyhedron(Pfull.A(1:mS, :),      Pfull.b(1:mS));
    Ph = Polyhedron(Pfull.A(mS+1:end, :),  Pfull.b(mS+1:end));

    % Keep Ph bounded by intersecting with cube in z-space
    Pcube = cube_poly_(d, cfg.Lcube);
    Ph    = Ph.intersect(Pcube);
    Ph    = Ph.minHRep;

    if cfg.ensure_full
        assert(~Ph.isEmptySet, 'Hard polyhedron Ph became empty after cube intersection.');
        assert(Ph.isFullDim,   'Hard polyhedron Ph is not full-dimensional.');
    end

    % Random quadratic cost in u (PSD)
    H = randn(nu);
    H = 0.5*(H'*H);
    F = randn(nu, nxi);
    Feta = randn(nu, neta);
    f = randn(nu, 1);

    % Extract blocks from z=[xi;u]   (xi first, u last)
    % For constraints: A_xi * xi + A_u * u <= b  ->  (A_u) u <= b - (A_xi) xi
    Axi_soft = Ps.A(:, 1:nxi);
    Au_soft  = Ps.A(:, nxi+1:end);
    hsoft    = Ps.b;

    Axi_hard = Ph.A(:, 1:nxi);
    Au_hard  = Ph.A(:, nxi+1:end);
    h        = Ph.b;

    % Map to your interface notation
    Ssoft = Axi_soft;
    Gsoft = Au_soft;

    S = Axi_hard;
    G = Au_hard;

    % Extra coupling for soft constraints: Ts * eta
    Tsoft = randn(size(Gsoft,1), neta);   % mS × neta

    % Pack
    Prob = struct();
    Prob.nu   = nu;
    Prob.nxi  = nxi;
    Prob.neta = neta;

    Prob.Ps    = Ps;
    Prob.Ph    = Ph;
    Prob.Pfull = Pfull;
    Prob.Pcube = Pcube;

    Prob.H    = H;
    Prob.F    = F;
    Prob.Feta = Feta;
    Prob.f    = f;

    Prob.Gsoft = Gsoft;
    Prob.Ssoft = Ssoft;
    Prob.Tsoft = Tsoft;
    Prob.hsoft = hsoft;

    Prob.G = G;
    Prob.S = S;
    Prob.h = h;

    Prob.mS = size(Gsoft,1);
    Prob.mH = size(G,1);
end


% =============================== Helpers (local) ===============================

function P = make_rand_poly_in_cube_(d, L, mCuts, cfg)
% make_rand_poly_in_cube_
% Build a random polytope inside cube: cube constraints + mCuts random cuts
% around a random interior point. Retries until nonempty full-dim.
%
% NOTE: this function is agnostic to variable meaning; caller uses z=[xi;u].

    if nargin < 4, cfg = struct(); end
    if ~isfield(cfg,'delta'),     cfg.delta     = 0.20; end
    if ~isfield(cfg,'r_min'),     cfg.r_min     = 0.30; end
    if ~isfield(cfg,'r_max'),     cfg.r_max     = 0.90; end
    if ~isfield(cfg,'max_retry'), cfg.max_retry = 50;   end
    if ~isfield(cfg,'minHRep'),   cfg.minHRep   = true; end

    if isscalar(L), L = L*ones(d,1); else, L = L(:); end
    assert(numel(L)==d,'L must be scalar or d×1.');

    A_cube = [ eye(d); -eye(d) ];
    b_cube = [ L; L ];

    Lin = (1 - cfg.delta)*L;
    Pin = Polyhedron([eye(d);-eye(d)], [Lin;Lin]);

    for tr = 1:cfg.max_retry
        z0 = Pin.randomPoint; z0 = z0(:);

        A_cut = zeros(mCuts, d);
        b_cut = zeros(mCuts, 1);
        for i = 1:mCuts
            ai = randn(d,1);
            ni = norm(ai,2);
            if ni < 1e-12, ai = [1; zeros(d-1,1)]; ni = 1; end
            ai = ai/ni;

            ri = cfg.r_min + (cfg.r_max - cfg.r_min)*rand(1);
            A_cut(i,:) = ai.';
            b_cut(i)   = ai.'*z0 + ri;
        end

        P = Polyhedron([A_cube; A_cut], [b_cube; b_cut]);
        if cfg.minHRep, P = P.minHRep; end

        if ~P.isEmptySet && P.isFullDim && all(P.A*z0 <= P.b + 1e-9)
            return;
        end
    end

    error('make_rand_poly_in_cube_: failed in %d tries.', cfg.max_retry);
end

function Pcube = cube_poly_(d, L)
% cube_poly_
% Return cube polyhedron in R^d: -L <= z <= L
    if isscalar(L), L = L*ones(d,1); else, L = L(:); end
    Pcube = Polyhedron([eye(d);-eye(d)], [L;L]);
end
