function info = api_supplement_cacheAct_(self, cfg)
    
    if nargin < 2, cfg = struct(); end
    if isfield(cfg,'seed') && ~isempty(cfg.seed), rng(cfg.seed); end

    Nc      = getfield_def_(cfg,'Nc',      128);
    tol_hit = getfield_def_(cfg,'tol_hit', 1e-9);
    info    = struct('nAdded',int32(0), 'bestCnt',int32(0), 'nAct1',int32(0));
    nu      = double(self.nu);
    
    % --- require Full cache ---
    if isempty(self.cache),fprintf('[api_supplement_cacheAct_] Full cache is empty.\n');return;end
    full    = self.cache;
    
    % --- ensure Act cache ---
    if isempty(self.cacheAct),self.cacheAct = cache_init_(double(self.nx), double(self.nu));end
    act     = self.cacheAct;
    
    F       = setdiff(int32(full.idList(:)), int32(act.idList(:)), 'stable');
    if isempty(F),fprintf('[api_supplement_cacheAct_] CacheAct has all regions.\n');return;end
    
  
    % ---------------- sample directions ---------------- 
    C = randn(nu, Nc); C = C ./ max(sqrt(sum(C.^2,1)), realmin);
    
    % ---------------- optional filter by Act ---------------- 
    actIds = int32(act.idList(:));
    if ~isempty(actIds)
        HAct = hit_matrix_(self, actIds, C, tol_hit);   % (#actIds x Nc)
        if any(HAct,1)
            C = C(:, any(HAct,1));
        end
    end
    
    % ---------------- choose bestC (fewest hits in F) ---------------- 
    HF  = hit_matrix_(self, F, C, tol_hit);             % (#F x nC)
    cnt = sum(HF, 1);
    [bestCnt, j] = min(cnt);                            % scalar + index
    
    hitF = HF(:, j);
    add_ids = F(hitF);
    
    if isempty(add_ids)
        return;
    end

    % ---------------- append ALL hit regions ---------------- 
    nAdded = int32(0);
    for t = 1:numel(add_ids)
        id = double(add_ids(t));
    
        A_blk = self.law{id}.Ax;
        b_blk = self.law{id}.bx;
        M_blk = self.law{id}.M;
        u_blk = self.law{id}.b;
    
        [act, added] = cache_append_(act, A_blk, b_blk, int32(id), M_blk, u_blk);
        if added, nAdded = nAdded + 1; end
    end
    
    self.cacheAct = act;
    
    info.nAdded  = nAdded;
    info.bestCnt = int32(bestCnt);
    info.nAct1   = int32(numel(act.idList));
end

% ======================= helper ======================= %

function H = hit_matrix_(self, ids, C, tol_hit)
% H(i,k)=true iff GI_inv(id(i))' * C(:,k) <= tol_hit elementwise.

    ids = int32(ids(:));
    nu  = size(C,1);
    nI  = numel(ids);
    nC  = size(C,2);
    
    A = zeros(nI*nu, nu);
    for i = 1:nI
        Gi = self.law{double(ids(i))}.GI_inv;  % expected nu x nu
        A((i-1)*nu + (1:nu), :) = Gi.';        % block = GI_inv'
    end
    
    Y = A * C;                     % (nI*nu) x nC
    Y = reshape(Y, nu, nI, nC);    % nu x nI x nC
    H = all(Y <= tol_hit, 1);          % 1 x nI x nC (logical)
    H = permute(H, [2 3 1]);           % nI x nC x 1
    H = reshape(H, nI, nC);            % nI x nC
end
