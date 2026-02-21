function [idOK, U, posOK] = query_(cache, xq, opt)
    if nargin < 3, opt = struct(); end
    tol = getfield_def_(opt,'tol_query',1e-7);

    xq = xq(:);

    nReg = numel(cache.idList);
    y    = cache.Aall * xq;
    viol = (y - cache.ball > tol);

    bad = false(nReg,1);
    bad(cache.row2pos(viol)) = true;
    posOK = find(~bad);
    idOK  = cache.idList(posOK);

    nu = size(cache.uball,2);
    if isempty(posOK)
        U = zeros(0, nu);
        return;
    end

    % rows for all selected regions, stacked by region blocks
    posOK = posOK(:).';                           % 1 x nOK
    rows  = (posOK-1)*nu + (1:nu).';              % nu x nOK
    rows  = rows(:);                              % (nu*nOK) x 1

    tmp = cache.M2(rows,:) * xq;                  % (nu*nOK) x 1
    U   = reshape(tmp, nu, []).' + cache.uball(posOK,:);   % nOK x nu
end
