function layers = build_pureNN_(nx, nu, hidden)
    if nargin < 3 || isempty(hidden), hidden = [64,64]; end

    if isscalar(hidden)
        hidden = [hidden hidden];
    else
        hidden = hidden(:).';   % row vector
    end

    layers = featureInputLayer(nx, 'Normalization','none', 'Name','in');

    for i = 1:numel(hidden)
        layers = [layers, ...
            fullyConnectedLayer(hidden(i), 'Name', "fc"+string(i)), ...
            reluLayer('Name', "relu"+string(i))]; %#ok<AGROW>
    end

    layers = [layers, fullyConnectedLayer(nu, 'Name', "fc_out"),regressionLayer];
end