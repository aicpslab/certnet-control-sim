function cfg = set_cert_default_cfg_()
% set_default_cfg_ 
% Single source of truth for all cfg/opt defaults used by cert codebase. 
%
% Notes 
% - All internal functions should assume these fields exist in opt_hot. 
% - Consistency: update_cacheAct => use_cacheAct. 

    cfg = struct();
    o   = struct();

    % ------------------------ Core build/query ------------------------ 
    o.tol_build = 1e-8;     % polyhedron normalization / VRep build tolerance
    o.rcond_thr = 1e-12;    % numerical stability threshold
    o.tol_query = o.tol_build * 1e1;     % membership tolerance in query_ (Ax*x <= bx + tol)

    % ------------------------ Active cache mode ----------------------- 
    % Two booleans kept for backward compatibility with current code. 
    o.use_cacheAct    = false;   % active-first query switch
    o.update_cacheAct = false;   % allow update when u is provided

    % ------------------------ Active update knobs --------------------- 
    % Used only if update_cacheAct = true (and thus use_cacheAct = true). 
    o.act_resThr  = 1e-7;     % accept update if ||u_hat - u|| <= resThr
    o.act_epsw    = 1e-12;   % sparsify threshold in Carath reduction

    % ------------------------ Consistency guard ----------------------- 
    if o.update_cacheAct
        o.use_cacheAct = true;
    end

    cfg.opt = o;
end
