function cfg = set_certnet_cfg_default_()
% certnet_cfg_default_  Centralized defaults for CertNet init/build.

    cfg = struct();

    % ---- normalization ----
    cfg.use_norm   = true;
    cfg.t_norm_eps = 1e-7;

    % ---- Scheme-1 params (g only) ----
    cfg.g_floor    = 1e-3;
    cfg.g_max      = 1e3;
    cfg.use_t_norm = 1;

    % ---- PHI architecture ----
    cfg.hidden     = 64;
    cfg.depth      = 2;
end
