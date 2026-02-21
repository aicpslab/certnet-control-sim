function [U, info] = api_vertices_(self, x, u)

    opt = self.opt_hot;

    xq = norm_x_(x(1:self.nx), self.sc.c_th(:), self.sc.d_th(:));

    if isempty(self.cache) || ~isstruct(self.cache)
        self.cache = build_cacheFull_(self.law);
    end
    cacheFull = self.cache;

    [U, segOK_used] = deal([], []);
    srcIsAct = false;

    if opt.use_cacheAct && ~isempty(self.cacheAct)
        [segOK_used, U] = query_(self.cacheAct, xq, opt);
        srcIsAct = ~isempty(U);
    end

    if srcIsAct && ~isempty(u) && ~isempty(segOK_used)
        ok = convex_rep_ok_(U, u, struct('epsw',opt.act_epsw,'resThr',opt.act_resThr,'use_qp',true));
        if ok
            info = struct('nFound', int32(size(U,1)));
            return;
        end
        [U, segOK_used, srcIsAct] = deal([], [], false);
    end

    if isempty(U)
        [segOK_used, U] = query_(cacheFull, xq, opt);
    end

    info = struct('nFound', int32(size(U,1)),'srcIsAct',srcIsAct,'id',segOK_used);

    if ~srcIsAct && opt.use_cacheAct && opt.update_cacheAct && ~isempty(u)
        act_try_update_(self, segOK_used, U, u, opt);
    end
end


function cache = build_cacheFull_(laws)
    [nx, nu] = deal(size(laws{1}.M,2), size(laws{1}.M,1));
    cache = cache_init_(nx, nu);

    for q = 1:numel(laws)
        cache = cache_append_(cache, laws{q}.Ax, laws{q}.bx, double(q), laws{q}.M, laws{q}.b);
    end
end

function act_try_update_(cert, segOK_used, U, u, opt)
    if isempty(u) || isempty(U) || isempty(segOK_used), return; end
    u = double(u(:));
    if numel(u) ~= cert.nu, return; end

    [nu, K] = deal(cert.nu, size(U,1));

    if isempty(cert.cacheAct)
        cert.cacheAct = cache_init_(cert.nx, cert.nu);
    end

    if K <= (nu+1)
        ids = segOK_used(:);
    else
        V  = double(U).';
        w0 = simplex_ls_(V, u, struct('use_qp',true));
        if isempty(w0), return; end
        [supp, ws] = carath_reduce_(V, w0, opt.act_epsw);
        if isempty(supp), return; end
        ids = segOK_used(supp(:));
        if numel(ids) > (nu+1), ids = ids(1:nu+1); end
    end

    for t = 1:numel(ids)
        qg = int32(ids(t));
        cert.cacheAct = cache_append_(cert.cacheAct, cert.law{qg}.Ax, cert.law{qg}.bx, double(qg), cert.law{qg}.M, cert.law{qg}.b);
    end
end
