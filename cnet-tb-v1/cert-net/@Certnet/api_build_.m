function api_build_(self, cert, cfg, nx)
    if nargin < 3 || isempty(cfg), cfg = struct(); end
    if nargin < 4, nx = []; end

    % ---- cfg defaults (centralized) ----
    cfg0 = set_certnet_cfg_default_();                 % <--- NEW
    cfg  = struct_merge_(cfg0, cfg);          % <--- NEW: user overrides defaults

    if isempty(nx), self.nx = cert.nx; else, self.nx = nx; end
    [self.cert, self.nu] = deal(cert, cert.nu);

    % ---- feature / normalization ----
    self.use_norm   = cfg.use_norm;
    self.t_norm_eps = cfg.t_norm_eps;

    % ---- Scheme-1 params (g only) ----
    self.g_floor   = cfg.g_floor;
    self.g_max     = cfg.g_max;
    self.use_t_norm = cfg.use_t_norm;

    % ---- PHI architecture ----
    hidden = cfg.hidden;
    depth  = cfg.depth;

    [self.x_mu, self.x_sig] = deal(zeros(1, self.nx), ones(1, self.nx));  % (1×nx)

    % PHI output: (nu + 1) = [t_raw; g_raw]
    out_dim = self.nu + 1;

    layers  = featureInputLayer(self.nx, 'Normalization','none', 'Name','in');
    for i = 1:depth
        layers = [layers, ...
            fullyConnectedLayer(hidden,'Name',"fc"+string(i)), ...
            reluLayer('Name',"relu"+string(i))]; %#ok<AGROW>
    end
    layers  = [layers, fullyConnectedLayer(out_dim,'Name',"fc"+string(depth+1))];

    self.phi = dlnetwork(layerGraph(layers));
    [self.Ws, self.bs] = export_phi_params_(self.phi);
end
