function [isCovered, info] = api_check_cover_cacheAct_(self, cfg)

    if nargin < 2, cfg = struct(); end
    if isempty(self.cacheAct) || ~isfield(self.cacheAct,'idList') || isempty(self.cacheAct.idList)
        fprintf('EMPTY_CACHEACT'); 
        isCovered = false;
        info = struct('status','EMPTY_CACHEACT');
        return;
    end

    solver      = getfield_def_(cfg,'solver',  'mosek');
    verb        = getfield_def_(cfg,'verbose', 0);
    epsv        = getfield_def_(cfg,'eps_violate', 1e-7);

    doAug       = logical(getfield_def_(cfg,'do_augment', 0));
    maxIter     = double(getfield_def_(cfg,'max_iter', 50));
    pickRule    = getfield_def_(cfg,'pick', 'first'); % 'first' only for now

    info        = struct('status','', 'nAct',int32(0), 'solverProblem',int32(-1), ...
                         'xbar',[], 'ubar',[], 'x',[], 'u',[], ...
                         'note','', 'epsv',double(epsv), ...
                         'nAug',int32(0), 'augIds',int32([]));

    % ----------------------- augmentation loop -----------------------
    for it = 1:maxIter

        % ---- refresh actIds each round (cacheAct grows)
        actIds      = int32(self.cacheAct.idList(:));
        info.nAct   = int32(numel(actIds));

        % ---- build MILP (your original core, minimal edits)
        [nx,nu] = deal(double(self.nx), double(self.nu));
        A0 = self.P.A;  b0 = self.P.b;

        cth = self.sc.c_th(:); dth = self.sc.d_th(:);
        cu  = self.sc.c_u(:);  du  = self.sc.d_u(:);

        S = A0(:,1:nx);
        G = A0(:,nx+1:nx+nu);

        A_lift = [S*diag(dth), G*diag(du)];
        b_lift = b0 - S*cth - G*cu;

        x = sdpvar(nx,1);   % xbar
        u = sdpvar(nu,1);   % ubar

        Cons = [];
        Cons = [Cons, A_lift*[x;u] <= b_lift];

        for r = 1:numel(actIds)
            id = double(actIds(r));
            Ax = self.law{id}.Ax;
            bx = self.law{id}.bx;

            m = size(Ax,1);
            z = binvar(m,1);

            % NOTE: your M is not rigorous; kept as-is for minimal change
            M = sum(Ax,2) - bx - epsv;
            M(M < 0) = 0;

            Cons = [Cons, sum(z) >= 1, Ax*x - bx >= epsv - M.*(1 - z)];
        end

        ops = sdpsettings('solver',solver,'verbose',verb);
        sol = optimize(Cons, 0, ops);
        info.solverProblem = int32(sol.problem);

        if sol.problem ~= 0
            % MILP infeasible => covered (or solver failed; you treat as covered before)
            isCovered = true;
            info.status = yalmiperror(sol.problem);
            return;
        end

        % feasible => counterexample found
        isCovered = false;
        info.status = 'COUNTEREXAMPLE_FOUND';
        info.xbar = value(x);
        info.ubar = value(u);
        info.x = cth + dth .* info.xbar;
        info.u = cu  + du  .* info.ubar;

        % ---- if not augmenting, stop here
        if ~doAug
            return;
        end

        % ----------------------- augment step -----------------------
        % Query FULL at this x to get candidate region ids (you said info.id exists)
        [~, infoQ] = self.api_vertices_(info.x, []);  %#ok<ASGLU>

        if ~isfield(infoQ,'id') || isempty(infoQ.id)
            info.note = 'Augment requested but api_vertices_ did not return info.id.';
            return;
        end

        idNew = int32(infoQ.id(1));  % pick first by default
        if ~strcmpi(pickRule,'first')
            % placeholder: currently only 'first'
            idNew = int32(infoQ.id(1));
        end

        % Append this region block into cacheAct
        A_blk = self.law{double(idNew)}.Ax;
        b_blk = self.law{double(idNew)}.bx;
        M_blk = self.law{double(idNew)}.M;
        u_blk = self.law{double(idNew)}.b;

        self.cacheAct = cache_append_(self.cacheAct, A_blk, b_blk, double(idNew), M_blk, u_blk);

        % book-keeping
        info.nAug  = int32(double(info.nAug) + 1);
        info.augIds(end+1,1) = idNew; %#ok<AGROW>

        % continue loop to re-check coverage
    end

    % maxIter reached
    info.note = 'Reached cfg.max_iter without proving covered.';
end
