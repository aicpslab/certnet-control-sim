function [XTrain, YTrain, info] = mpqp_gen_trainingData(Ph, nu, nxi, neta, OPbase, Ntrain, cfgEta, cfgMix)
% mpqp_gen_trainingData (experiment version)
%
% Assumptions:
%   - Ph.V uses the stacked variable z = [xi; u], i.e., columns are [xi | u].
%   - We generate training inputs XTrain = [xi, eta].
%   - Labels YTrain are produced by OPbase{xi, eta} -> u.
%
% Sampling of convex weights (NO -log(rand)):
%   - We use the "sorted-uniform gaps" method to sample Dirichlet(1),
%     i.e., uniform on the simplex.
%
% cfgMix.type options:
%   - 'dirichlet' : full Dirichlet(1) weights over all Nv vertices
%   - 'k_sparse'  : pick K vertices per sample, Dirichlet(1) weights on those K
%   - 'single'    : pick 1 vertex per sample
%   - 'two'       : convex combination of 2 vertices per sample
%
% cfgEta.type options:
%   - 'gauss' : eta ~ N(0, sigma^2 I)
%   - 'unif'  : eta ~ Uniform([-L, L]) elementwise

    if nargin < 7 || isempty(cfgEta), cfgEta = struct(); end
    if nargin < 8 || isempty(cfgMix), cfgMix = struct(); end

    % ---- lightweight defaults (experiment-friendly) ----
    if ~isfield(cfgEta,'type'), cfgEta.type = 'gauss'; end
    if ~isfield(cfgMix,'type'), cfgMix.type = 'k_sparse'; end

    V  = Ph.V;              % Nv × (nxi+nu), with columns [xi | u]
    Nv = size(V,1);
    Vxi = V(:, 1:nxi);      % xi block (xi first)

    if ~isfield(cfgMix,'K') || isempty(cfgMix.K), cfgMix.K = min(4, Nv); end
    if ~isfield(cfgEta,'sigma') || isempty(cfgEta.sigma), cfgEta.sigma = 1; end
    if ~isfield(cfgEta,'L') || isempty(cfgEta.L), cfgEta.L = 1; end

    % ---- sample xi ----
    XiTrain = zeros(Ntrain, nxi);

    switch lower(cfgMix.type)
        case 'dirichlet'
            % Full Dirichlet(1) over all Nv vertices (uniform on simplex)
            Lambda  = simplex_dir1_(Ntrain, Nv);   % Ntrain×Nv
            XiTrain = Lambda * Vxi;

        case {'k_sparse','sparse'}
            % Pick K vertices per sample, Dirichlet(1) weights on those K only
            K = min(max(1, cfgMix.K), Nv);
            for i = 1:Ntrain
                idx = randperm(Nv, K);
                w   = simplex_dir1_(1, K);         % 1×K
                XiTrain(i,:) = w * Vxi(idx,:);
            end

        case 'single'
            % Pick a single vertex (no mixing)
            idx = randi(Nv, Ntrain, 1);
            XiTrain = Vxi(idx,:);

        case 'two'
            % Mix two randomly chosen vertices with a random scalar weight
            idx1 = randi(Nv, Ntrain, 1);
            idx2 = randi(Nv, Ntrain, 1);
            a = rand(Ntrain, 1);
            XiTrain = a .* Vxi(idx1,:) + (1 - a) .* Vxi(idx2,:);

        otherwise
            error('Unknown cfgMix.type: %s', cfgMix.type);
    end

    % ---- sample eta independently ----
    switch lower(cfgEta.type)
        case 'gauss'
            EtaTrain = cfgEta.sigma * randn(Ntrain, neta);

        case 'unif'
            L = cfgEta.L;
            if isscalar(L), L = L*ones(1,neta); else, L = reshape(L,1,[]); end
            EtaTrain = (2*rand(Ntrain, neta) - 1) .* L;

        otherwise
            error('Unknown cfgEta.type: %s', cfgEta.type);
    end

    % ---- concatenate training inputs ----
    XTrain = [XiTrain, EtaTrain];

    % ---- label by OPbase{xi, eta} ----
    YTrain  = zeros(Ntrain, nu);
    failIdx = false(Ntrain,1);

    for i = 1:Ntrain
        xi  = XTrain(i, 1:nxi).';
        eta = XTrain(i, nxi+1:nxi+neta).';
        try
            ui = OPbase{xi, eta};
            if isempty(ui) || any(~isfinite(ui))
                failIdx(i) = true;
            else
                YTrain(i,:) = ui(:).';
            end
        catch
            failIdx(i) = true;
        end
    end

    % ---- info ----
    info.Ntrain    = Ntrain;
    info.Nv        = Nv;
    info.failCount = nnz(failIdx);
    info.failFrac  = info.failCount / max(Ntrain,1);
    info.failIdx   = find(failIdx);
    info.cfgEta    = cfgEta;
    info.cfgMix    = cfgMix;
end


function W = simplex_dir1_(N, K)
% simplex_dir1_
% Sample Dirichlet(1) weights (uniform on the simplex) using sorted-uniform gaps:
%   1) draw K-1 i.i.d. Uniform(0,1) numbers
%   2) sort them
%   3) take consecutive differences (gaps), including 0 and 1 endpoints
% Output:
%   W is N×K, each row is nonnegative and sums to 1.

    if K == 1
        W = ones(N,1);
        return;
    end

    U = sort(rand(N, K-1), 2);
    W = diff([zeros(N,1), U, ones(N,1)], 1, 2);   % N×K
end
