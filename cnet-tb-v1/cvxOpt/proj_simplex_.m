function w = proj_simplex_(v)
% proj_simplex_ //
% Euclidean projection onto simplex {w>=0, sum w = 1} //
%
% Input:
%   v : n×1 (or any vector)
% Output:
%   w : n×1

    v = double(v(:));
    n = numel(v);

    u    = sort(v,'descend');
    cssv = cumsum(u) - 1;
    rho  = find(u - cssv./(1:n)' > 0, 1, 'last');

    if isempty(rho)
        w = zeros(n,1);
        w(1) = 1;
        return;
    end

    theta = cssv(rho)/rho;
    w     = max(v - theta, 0);
end
