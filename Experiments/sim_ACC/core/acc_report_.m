function Rep = acc_report_(out, opt)
% acc_report_
% Compact report (FOC/CA-style).
% Default: ignore plot-only methods (CertNetRaw, CERT).
%
% Inputs:
%   out: struct from acc_test_closedloop_
%   opt (optional):
%     .ignore_plot_only (default true)
%
% Output:
%   Rep.lines : cellstr of printed lines

    if nargin < 2 || isempty(opt), opt = struct(); end

    ignore_plot_only = true;
    if isfield(opt,'ignore_plot_only') && ~isempty(opt.ignore_plot_only)
        ignore_plot_only = logical(opt.ignore_plot_only);
    end

    names = out.names; M = numel(names);
    nTest = out.nTest;
    epsf  = out.eps_feas;

    keep = true(M,1);
    if ignore_plot_only && isfield(out,'plot_only') && ~isempty(out.plot_only)
        keep = ~out.plot_only(:);
    end
    idx = find(keep);

    lines = {};
    lines{end+1} = sprintf('==================== ACC REPORT (CLOSEDLOOP) ====================');
    lines{end+1} = sprintf('Ts = %.0fus | eps_feas = %.1e | nTest = %d', out.Ts_us, epsf, nTest);
    lines{end+1} = sprintf('');
    lines{end+1} = sprintf('Columns: time_us(mean/p50/p99) | occ(mean/p99) | miss_rate | iface(vmax/rate) | hk1<0(rate) | J(mean/p95)');
    lines{end+1} = sprintf('---------------------------------------------------------------------------------------------------------------');
    lines{end+1} = sprintf('%-12s | %-18s | %-13s | %-9s | %-16s | %-9s | %-14s', ...
        'Method','time_us','occ','miss','iface','hk1<0','J');
    lines{end+1} = sprintf('---------------------------------------------------------------------------------------------------------------');

    for ii = 1:numel(idx)
        j = idx(ii);

        t  = out.time_us(:,j);
        tn = t(~isnan(t));
        if isempty(tn), tn = nan; end

        t_mean = mean(tn,'omitnan');
        t_p50  = prctile(tn,50);
        t_p99  = prctile(tn,99);

        occ_mean = out.occ_mean(j);
        occ_p99  = out.occ_p99(j);
        miss     = out.miss_rate(j);

        vmax_max = max(out.vmax(:,j),[],'omitnan');
        vrate    = out.vrate(j);
        hrate    = out.hrate(j);

        Jv = out.track(:,j);
        Jn = Jv(~isnan(Jv));
        if isempty(Jn), Jn = nan; end
        J_mean = mean(Jn,'omitnan');
        J_p95  = prctile(Jn,95);

        lines{end+1} = sprintf('%-12s | %7.1f/%6.1f/%6.1f | %6.3f/%6.3f | %7.2f%% | %9.2e/%6.2f%% | %7.2f%% | %9.2e/%9.2e', ...
            names{j}, ...
            t_mean, t_p50, t_p99, ...
            occ_mean, occ_p99, ...
            100*miss, ...
            vmax_max, 100*vrate, ...
            100*hrate, ...
            J_mean, J_p95);
    end

    lines{end+1} = sprintf('---------------------------------------------------------------------------------------------------------------');

    Rep = struct();
    Rep.lines = lines;
end
