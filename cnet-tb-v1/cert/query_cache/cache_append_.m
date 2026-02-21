function [cache, added] = cache_append_(cache, A_blk, b_blk, id, M_blk, u_blk)

    if ~isempty(cache.idList) && any(cache.idList == id)
        added = false;
        return;
    end

    [added, pos] = deal(true, numel(cache.idList) + 1);

    cache.Aall    = [cache.Aall; A_blk];
    cache.ball    = [cache.ball; b_blk];
    cache.row2pos = [cache.row2pos; repmat(pos, size(A_blk,1), 1)];
    cache.idList  = [cache.idList; id];

    % ---- 2D M storage ----
    % M_blk must be nu x nx
    cache.M2 = [cache.M2; M_blk];

    cache.uball = [cache.uball; u_blk(:).'];
end
