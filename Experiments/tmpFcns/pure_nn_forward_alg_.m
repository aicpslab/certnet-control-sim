function y = pure_nn_forward_alg_(Alg, x)
    a = (x(:));

    % normalize ONCE
    if isfield(Alg,'muX') && isfield(Alg,'sigX') && ~isempty(Alg.muX) && ~isempty(Alg.sigX)
        a = (a - Alg.muX(:)) ./ Alg.sigX(:);
    end

    assert(isfield(Alg,'Ws') && isfield(Alg,'bs') && ~isempty(Alg.Ws), 'PureNNAlg: missing Ws/bs.');
    assert(size(Alg.Ws{1},2) == numel(a), 'PureNNAlg: input dimension mismatch.');

    L = numel(Alg.Ws);
    for l = 1:L
        a = Alg.Ws{l}*a + Alg.bs{l};
        if l < L
            a(a<0) = 0; % ReLU
        end
    end
    y = a;
end