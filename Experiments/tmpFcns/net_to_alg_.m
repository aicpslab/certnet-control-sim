function Alg = net_to_alg_(net)
    L = net.Layers;

    isFC = arrayfun(@(x) isa(x,'nnet.cnn.layer.FullyConnectedLayer'), L);
    fc   = L(isFC);

    Ws = cell(numel(fc),1);
    bs = cell(numel(fc),1);

    for i = 1:numel(fc)
        Ws{i} = single(fc(i).Weights);
        bs{i} = single(fc(i).Bias);
    end

    Alg = struct();
    Alg.Ws   = Ws;
    Alg.bs   = bs;
    Alg.muX  = [];   % optional normalization
    Alg.sigX = [];
 end