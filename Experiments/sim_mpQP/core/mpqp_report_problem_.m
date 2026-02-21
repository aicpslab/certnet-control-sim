function T = mpqp_report_problem_(out, cfg)
% mpqp_report_problem_
% Print a compact benchmark report and optionally return a one-row table.
%
% Inputs:
%   out: output of mpqp_test_problem_
%   cfg (optional):
%     .name          (default 'MPQP')
%     .tol_viol      (default out.summary.viol.tol if exists else 1e-7)
%     .return_table  (default true)
%     .print_speedup (default true)

    if nargin < 2, cfg = struct(); end
    if ~isfield(cfg,'name'), cfg.name = 'MPQP'; end
    if ~isfield(cfg,'return_table'), cfg.return_table = true; end
    if ~isfield(cfg,'print_speedup'), cfg.print_speedup = true; end

    S = out.summary;

    if isfield(cfg,'tol_viol')
        tol = cfg.tol_viol;
    elseif isfield(S,'viol') && isfield(S.viol,'tol')
        tol = S.viol.tol;
    else
        tol = 1e-7;
    end

    usePWA = isfield(S,'timing') && isfield(S.timing,'pwa') && ~isempty(S.timing.pwa);

    fprintf('\n============================================================\n');
    fprintf('[%s] Report\n', cfg.name);
    fprintf('------------------------------------------------------------\n');

    fprintf('Timing (us)  [mean / p50 / p99 / max]\n');
    print_timing_row_('QP',   S.timing.qp);
    if usePWA, print_timing_row_('PWA',  S.timing.pwa); end
    print_timing_row_('PureNN', S.timing.nn);
    print_timing_row_('NN+Proj',S.timing.prj);
    print_timing_row_('CertNet',S.timing.cn);

    if cfg.print_speedup && isfield(out,'timing_us')
        fprintf('Speedup vs QP: t_QP / t_method  [mean / p50 / p99 / max]\n');
        tq = out.timing_us.qp(:);

        if usePWA && isfield(out.timing_us,'pwa')
            st = speedup_stats_(tq, out.timing_us.pwa(:));
            print_speedup_row_('PWA', st);
        end

        st = speedup_stats_(tq, out.timing_us.nn(:));  print_speedup_row_('PureNN', st);
        st = speedup_stats_(tq, out.timing_us.prj(:)); print_speedup_row_('NN+Proj', st);
        st = speedup_stats_(tq, out.timing_us.cn(:));  print_speedup_row_('CertNet', st);
    end

    if isfield(S,'viol') && ~isempty(S.viol)
        fprintf('Hard feasibility: vmax / rate(>%.1e)\n', tol);
        print_viol_row_('QP',     S.viol.qp);
        if usePWA, print_viol_row_('PWA', S.viol.pwa); end
        print_viol_row_('PureNN', S.viol.nn);
        print_viol_row_('NN+Proj',S.viol.prj);
        print_viol_row_('CertNet',S.viol.cn);
    end

    if isfield(S,'mse') && ~isempty(S.mse)
        fprintf('Performance (u-MSE vs QP): mean / p95 / max\n');
        if usePWA, print_mse_row_('PWA', S.mse.pwa); end
        print_mse_row_('PureNN',  S.mse.nn);
        print_mse_row_('NN+Proj', S.mse.prj);
        print_mse_row_('CertNet', S.mse.cn);
    end

    if isfield(S,'failCounts')
        fc = S.failCounts;
        fprintf('Failures: QP=%d', fc.qp);
        if isfield(fc,'pwa'), fprintf(' | PWA=%d', fc.pwa); end
        fprintf(' | NN=%d | Proj=%d | CN=%d\n', fc.nn, fc.prj, fc.cn);
    end

    if isfield(S,'pwaStatus')
        fprintf('PWA status=%s', string(S.pwaStatus));
        if isfield(S,'pwaNr') && ~isnan(S.pwaNr), fprintf(' | Nr=%d', S.pwaNr); end
        fprintf('\n');
    end

    fprintf('============================================================\n');

    if ~cfg.return_table
        T = [];
        return;
    end

    % one-row table (main numbers only)
    T = table(string(cfg.name), ...
        S.timing.qp.mean, S.timing.qp.p50, S.timing.qp.p99, S.timing.qp.max, ...
        S.timing.nn.mean, S.timing.nn.p50, S.timing.nn.p99, S.timing.nn.max, ...
        S.timing.prj.mean,S.timing.prj.p50,S.timing.prj.p99,S.timing.prj.max, ...
        S.timing.cn.mean, S.timing.cn.p50, S.timing.cn.p99, S.timing.cn.max);

    T.Properties.VariableNames = { ...
        'name', ...
        'qp_mean','qp_p50','qp_p99','qp_max', ...
        'nn_mean','nn_p50','nn_p99','nn_max', ...
        'pr_mean','pr_p50','pr_p99','pr_max', ...
        'cn_mean','cn_p50','cn_p99','cn_max' ...
    };
end


% ---------------- local helpers ----------------

function print_timing_row_(name, st)
    fprintf('[%-8s] %8.3f / %8.3f / %8.3f / %8.3f\n', name, st.mean, st.p50, st.p99, st.max);
end

function print_viol_row_(name, st)
    fprintf('[%-8s] %.3e / %.2f%%\n', name, st.max, 100*st.rate);
end

function print_mse_row_(name, st)
    fprintf('[%-8s] %.3e / %.3e / %.3e\n', name, st.mean, st.p95, st.max);
end

function print_speedup_row_(name, st)
    fprintf('[%-8s] %8.3f / %8.3f / %8.3f / %8.3f\n', name, st.mean, st.p50, st.p99, st.max);
end

function st = speedup_stats_(t_qp, t_m)
    tq = t_qp(:);
    tm = t_m(:);
    ok = isfinite(tq) & isfinite(tm) & (tm > 0);
    r  = tq(ok) ./ tm(ok);
    st = struct();
    st.mean = mean(r);
    st.p50  = prctile(r,50);
    st.p99  = prctile(r,99);
    st.max  = max(r);
end
