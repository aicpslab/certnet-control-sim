function Rep = ca_report_(out, opt)
% ========================================================================
% ca_report_ // Report key stats from ca_test_sync_inject_ output "out"
%
% Reports (deadline run):
%   time_us(mean/p50/p99) | occ(mean/p99) | miss/E[o]/p99(o>0)/max(o) | feas(vmax/rate) | tr(mean/p95)
%
% Also reports (oracle rerun, if any):
%   tr(mean/p95) + time_us(mean/p50/p99)  (no miss by definition)
%
% Inputs:
%   out : from ca_test_sync_inject_
%   opt : struct (optional)
%     .eps_feas = 1e-7
%     .print    = true
% ========================================================================

if nargin < 2 || isempty(opt), opt = struct(); end
if ~isfield(opt,'eps_feas'), opt.eps_feas = 1e-7; end
if ~isfield(opt,'print'), opt.print = true; end

eps_feas = opt.eps_feas;

Ts_us = out.meta.Ts_us;
WDtest = out.ref.WDtest;

names = {'Opt','NN','NNp','CN'};
dispNames = {'Opt','NN','NN+Proj','CertNet'};

Rep = struct();
Rep.meta = out.meta;
Rep.stats = struct(); Rep.stats.deadline = struct(); Rep.stats.oracle = struct();
Rep.lines = {};

hdr1 = sprintf('==================== CONTROL ALLOCATION REPORT (nu=%d, nw=%d) ====================', out.meta.nu, out.meta.nw);
hdr2 = sprintf('Ts = %.0fus | miss_thr = %.2f | nTest = %d | sync inject + hold-on-timeout', Ts_us, out.meta.miss_thr, out.meta.nTest);
hdr3 = 'Columns: time_us(mean/p50/p99) | occ(mean/p99) | miss/E[o]/p99(o>0)/max(o) | feas(vmax/rate) | tr(mean/p95)';
sep  = repmat('-', 1, 140);

Rep.lines{end+1} = hdr1;
Rep.lines{end+1} = hdr2;
Rep.lines{end+1} = '';
Rep.lines{end+1} = hdr3;
Rep.lines{end+1} = sep;
Rep.lines{end+1} = sprintf('%-8s | %-18s | %-12s | %-32s | %-16s | %-16s', 'Method', 'time_us', 'occ', 'overshoot', 'feas', 'track');
Rep.lines{end+1} = sep;

for j = 1:numel(names)
    nm = names{j}; dn = dispNames{j};

    t_us = out.deadline.(nm).t_us(:);
    occ  = t_us ./ Ts_us;
    miss = out.deadline.(nm).miss(:);

    o = max(occ - 1, 0);
    o_pos = o(o > 0);

    res = out.deadline.(nm).rhs_max(:);
    w   = out.deadline.(nm).w;
    e   = w - WDtest;
    tr  = sum(e.^2, 2);

    st = struct();
    [st.t_mean, st.t_p50, st.t_p99] = deal(nanmean_(t_us), nanprctile_(t_us,50), nanprctile_(t_us,99));
    [st.occ_mean, st.occ_p99] = deal(nanmean_(occ), nanprctile_(occ,99));
    st.miss_rate = 100*nanmean_(double(miss));
    st.Eo = nanmean_(o);
    st.p99_o_pos = ternary_(isempty(o_pos), 0, nanprctile_(o_pos,99));
    st.max_o = ternary_(isempty(o), 0, max(o));
    st.vmax = max(res);
    st.vrate = 100*mean(res > eps_feas);
    [st.tr_mean, st.tr_p95] = deal(nanmean_(tr), nanprctile_(tr,95));

    Rep.stats.deadline.(nm) = st;

    s_time = sprintf('%6.1f/%6.1f/%6.1f', st.t_mean, st.t_p50, st.t_p99);
    s_occ  = sprintf('%5.3f/%5.3f', st.occ_mean, st.occ_p99);
    s_ov   = sprintf('%6.2f%%/%6.3f/%6.3f/%6.3f', st.miss_rate, st.Eo, st.p99_o_pos, st.max_o);
    s_feas = sprintf('%8.2e/%6.2f%%', st.vmax, st.vrate);
    s_tr   = sprintf('%8.2e/%8.2e', st.tr_mean, st.tr_p95);

    Rep.lines{end+1} = sprintf('%-8s | %-18s | %-12s | %-32s | %-16s | %-16s', dn, s_time, s_occ, s_ov, s_feas, s_tr);
end

Rep.lines{end+1} = sep;

% ---------------- Oracle rerun summary (quality upper bound) ----------------
rerun_names = out.oracle.rerun.names;
Rep.lines{end+1} = '';
if isempty(rerun_names)
    Rep.lines{end+1} = 'Oracle rerun: none (no method exceeded miss_thr).';
else
    Rep.lines{end+1} = sprintf('Oracle rerun (NO deadline, always inject) for: %s', strjoin(rerun_names, ', '));
    Rep.lines{end+1} = 'Oracle columns: time_us(mean/p50/p99) | feas(vmax/rate) | tr(mean/p95)';
    Rep.lines{end+1} = sep;
    Rep.lines{end+1} = sprintf('%-8s | %-18s | %-16s | %-16s', 'Method', 'time_us', 'feas', 'track');
    Rep.lines{end+1} = sep;

    for j = 1:numel(rerun_names)
        nm = rerun_names{j};
        dn = dispNames{strcmp(names,nm)};

        t_us = out.oracle.(nm).t_us(:);
        res  = out.oracle.(nm).rhs_max(:);
        w    = out.oracle.(nm).w;
        e    = w - WDtest;
        tr   = sum(e.^2, 2);

        st = struct();
        [st.t_mean, st.t_p50, st.t_p99] = deal(nanmean_(t_us), nanprctile_(t_us,50), nanprctile_(t_us,99));
        st.vmax = max(res);
        st.vrate = 100*mean(res > eps_feas);
        [st.tr_mean, st.tr_p95] = deal(nanmean_(tr), nanprctile_(tr,95));

        Rep.stats.oracle.(nm) = st;

        s_time = sprintf('%6.1f/%6.1f/%6.1f', st.t_mean, st.t_p50, st.t_p99);
        s_feas = sprintf('%8.2e/%6.2f%%', st.vmax, st.vrate);
        s_tr   = sprintf('%8.2e/%8.2e', st.tr_mean, st.tr_p95);

        Rep.lines{end+1} = sprintf('%-8s | %-18s | %-16s | %-16s', dn, s_time, s_feas, s_tr);
    end
    Rep.lines{end+1} = sep;
end

if opt.print
    fprintf('%s\n', strjoin(Rep.lines, newline));
end

end

% ===================== small helpers (local) =====================
function m = nanmean_(x)
x = x(:); x = x(isfinite(x));
if isempty(x), m = NaN; else, m = mean(x); end
end

function q = nanprctile_(x, p)
x = x(:); x = x(isfinite(x));
if isempty(x), q = NaN; else, q = prctile(x, p); end
end

function y = ternary_(cond, a, b)
if cond, y = a; else, y = b; end
end
