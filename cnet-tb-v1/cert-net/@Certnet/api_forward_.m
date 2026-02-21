function y = api_forward_(self, x)
    % ------------------------------ PHI ---------------------------------
    x_phi      = norm_x_(x, self.x_mu', self.x_sig');

    out        = inf_phi_forward_fast_(self, x_phi);                               % (nu+1)x1
    [t_dir, g] = inf_split_tg_(self, out);

    % ------------------------------ CERT --------------------------------
    V       = self.cert.vertices(x(1:self.cert.nx).');                          % K x nu

    % ------------------------------ POST --------------------------------
    t       = g * t_dir;

    s       = V * t;                                                     % stable softmax
    
    w = simplex_cus(s);

    y       = V.' * w;      
end

function out = inf_phi_forward_fast_(self, x_phi)

    h   = x_phi;
    L   = numel(self.Ws);
    for i = 1:(L-1)
        h = max(self.Ws{i}*h + self.bs{i}(:), 0);
    end
    out = self.Ws{L}*h + self.bs{L}(:);                                         % (nu+1)x1
end

function [t_dir, g] = inf_split_tg_(self, out)

    t_raw   = out(1:self.nu);
    g_raw   = out(self.nu+1);

    % ---- t direction ----
    t_dir   = t_raw;
    if self.use_t_norm && self.nu > 1
        t_dir = t_dir ./ (sqrt(sum(t_dir.^2)) + self.t_norm_eps);
    end

    % ---- g gate ----
    g       = softplus_(g_raw) + self.g_floor;
    if ~isempty(self.g_max) && self.g_max > 0
        g   = g - max(g - self.g_max, 0);                                       % dlarray-safe cap
    end
end
