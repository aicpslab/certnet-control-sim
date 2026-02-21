function fig = mpqp_plot_problem2_(out1, out2, cfg)
% mpqp_plot_problem2_
% Paper-ready 2x4 summary figure (double-column width).
% Row 1: out1, Row 2: out2
% Cols: (1) Timing CDF, (2) Violation CDF (signed-log), (3) Timing summary, (4) Pareto
%
% Optional side legend can be placed on the far left.
% (Row labels S1/S2 removed; describe row meanings in the figure caption.)
%
% Requires out.store_arrays=true in mpqp_test_problem_.

if nargin < 3, cfg = struct(); end
cfg = fill_cfg_(cfg);

req_fields_(out1);
req_fields_(out2);

usePWA1 = cfg.show_pwa && has_pwa_(out1);
usePWA2 = cfg.show_pwa && has_pwa_(out2);

if ~exist(cfg.outdir,'dir'), mkdir(cfg.outdir); end

fig = figure(gcf); clf(fig);
set(fig,'Units','inches','Position',[1 1 cfg.fig_w_in cfg.fig_h_in],'Color','w','Renderer','painters');
set(fig,'PaperUnits','inches','PaperPosition',[0 0 cfg.fig_w_in cfg.fig_h_in],'PaperSize',[cfg.fig_w_in cfg.fig_h_in]);

% Use most of the canvas. If legend is enabled, it will be drawn in the left margin.
tl = tiledlayout(2,4,'Padding','compact','TileSpacing','compact');
tl.Units = 'normalized';
tl.OuterPosition = [0.03 0.06 0.96 0.94];

% ---------- Row 1 ----------
ax11 = nexttile(tl,1); setup_ax_(ax11,cfg);
plot_timing_cdf_(ax11, out1, usePWA1, cfg);
title(ax11,'(a) Timing CDF','Interpreter','latex');
ylabel(ax11,'$P(t \le \tau)$','Interpreter','latex');

ax12 = nexttile(tl,2); setup_ax_(ax12,cfg);
plot_viol_cdf_signedlog_(ax12, out1, usePWA1, cfg);
title(ax12,'(b) Violation CDF','Interpreter','latex');
ylabel(ax12,'$P(\mathrm{viol} \le x)$','Interpreter','latex');

ax13 = nexttile(tl,3); setup_ax_(ax13,cfg);
plot_timing_summary_(ax13, out1, usePWA1, cfg);
title(ax13,'(c) p50-p99+mean','Interpreter','latex');

ax14 = nexttile(tl,4); setup_ax_(ax14,cfg);
plot_pareto_(ax14, out1, cfg);
title(ax14,'(d) Pareto','Interpreter','latex');

% ---------- Row 2 ----------
ax21 = nexttile(tl,5); setup_ax_(ax21,cfg);
plot_timing_cdf_(ax21, out2, usePWA2, cfg);
title(ax21,'(e) Timing CDF','Interpreter','latex');
ylabel(ax21,'$P(t \le \tau)$','Interpreter','latex');

ax22 = nexttile(tl,6); setup_ax_(ax22,cfg);
plot_viol_cdf_signedlog_(ax22, out2, usePWA2, cfg);
title(ax22,'(f) Violation CDF','Interpreter','latex');
ylabel(ax22,'$P(\mathrm{viol} \le x)$','Interpreter','latex');

ax23 = nexttile(tl,7); setup_ax_(ax23,cfg);
plot_timing_summary_(ax23, out2, usePWA2, cfg);
title(ax23,'(g) p50-p99+mean','Interpreter','latex');

ax24 = nexttile(tl,8); setup_ax_(ax24,cfg);
plot_pareto_(ax24, out2, cfg);
title(ax24,'(h) Pareto','Interpreter','latex');

% ---------- Axis labels (reduce clutter) ----------
xlabel(ax11,''); xlabel(ax12,''); xlabel(ax13,''); xlabel(ax14,'');
xlabel(ax21,'$\tau\ (\mu\mathrm{s})$','Interpreter','latex');
xlabel(ax22,'violation','Interpreter','latex');
xlabel(ax23,'runtime ($\mu$s)','Interpreter','latex');
xlabel(ax24,'runtime ($\mu$s)','Interpreter','latex');

% ---------- Side legend (optional) ----------
if cfg.show_legend
    add_side_method_legend_(fig, [ax11 ax12 ax13 ax14 ax21 ax22 ax23 ax24], cfg);
end

% ---------- Export ----------
if cfg.do_export
    pdf_path = fullfile(cfg.outdir, [cfg.export_name '.pdf']);
    print(fig, pdf_path, '-dpdf', '-painters');
    if cfg.export_eps
        eps_path = fullfile(cfg.outdir, [cfg.export_name '.eps']);
        print(fig, eps_path, '-depsc2', '-painters');
        fprintf('[mpqp_plot_problem2_] saved: %s and %s\n', pdf_path, eps_path);
    else
        fprintf('[mpqp_plot_problem2_] saved: %s\n', pdf_path);
    end
end

end

% ====================== helpers ======================

function cfg = fill_cfg_(cfg)
if ~isfield(cfg,'outdir'), cfg.outdir = 'Figures'; end
if ~isfield(cfg,'export_name'), cfg.export_name = 'sim_mpQP'; end
if ~isfield(cfg,'do_export'), cfg.do_export = true; end
if ~isfield(cfg,'export_eps'), cfg.export_eps = false; end

if ~isfield(cfg,'fig_w_in'), cfg.fig_w_in = 7.0; end
if ~isfield(cfg,'fig_h_in'), cfg.fig_h_in = 3.4; end
if ~isfield(cfg,'fs'), cfg.fs = 9; end
if ~isfield(cfg,'leg_fs'), cfg.leg_fs = 8; end

if ~isfield(cfg,'use_logx_timing'), cfg.use_logx_timing = true; end
if ~isfield(cfg,'use_loglog_pareto'), cfg.use_loglog_pareto = true; end
if ~isfield(cfg,'show_pwa'), cfg.show_pwa = true; end
if ~isfield(cfg,'show_legend'), cfg.show_legend = false; end

if ~isfield(cfg,'viol_v0'), cfg.viol_v0 = 1e-12; end
if ~isfield(cfg,'viol_mark'), cfg.viol_mark = 1e-6; end

if ~isfield(cfg,'cdf_lw'), cfg.cdf_lw = 1.0; end
if ~isfield(cfg,'cdf_cn_lw'), cfg.cdf_cn_lw = 1.6; end
if ~isfield(cfg,'pt_size'), cfg.pt_size = 7; end

if ~isfield(cfg,'nu'), cfg.nu = []; end

if ~isfield(cfg,'annot_timing_vals'), cfg.annot_timing_vals = 0; end
if ~isfield(cfg,'annot_fs'), cfg.annot_fs = 6.2; end
if ~isfield(cfg,'annot_fmt'), cfg.annot_fmt = '%.1f'; end

cfg.st = struct();
cfg.st.qp  = [0.35 0.35 0.35];
cfg.st.nn  = [0.12 0.44 0.70];
cfg.st.prj = [0.00 0.62 0.52];
cfg.st.cn  = [0.78 0.24 0.26];
cfg.st.pwa = [0.00 0.00 0.00];
end

function setup_ax_(ax,cfg)
box(ax,'on'); grid(ax,'on'); hold(ax,'on');
set(ax,'FontSize',cfg.fs,'TickLabelInterpreter','latex','LineWidth',0.75,'Box','on');
set(ax,'XMinorGrid','off','YMinorGrid','off');
try, set(ax,'GridAlpha',0.20); catch, end
try, set(ax,'LooseInset',max(ax.TightInset, 0.01)); catch, end
end

function req_fields_(out)
must = {'timing_us','viol','mse'};
for i = 1:numel(must)
    assert(isfield(out,must{i}), 'Missing out.%s (need store_arrays=true).', must{i});
end
end

function tf = has_pwa_(out)
tf = isfield(out,'timing_us') && isfield(out.timing_us,'pwa') && any(isfinite(out.timing_us.pwa(:))) && ...
     isfield(out,'viol') && isfield(out.viol,'pwa') && any(isfinite(out.viol.pwa(:))) && ...
     isfield(out,'mse') && isfield(out.mse,'pwa') && any(isfinite(out.mse.pwa(:)));
end

function plot_timing_cdf_(ax, out, usePWA, cfg)
keys = {'qp','nn','prj','cn'};
Tlist = {out.timing_us.qp(:), out.timing_us.nn(:), out.timing_us.prj(:), out.timing_us.cn(:)};
if usePWA
    keys  = [{'pwa'}, keys];
    Tlist = [{out.timing_us.pwa(:)}, Tlist];
end

for k = 1:numel(Tlist)
    t = Tlist{k};
    t = t(isfinite(t));
    if numel(t) < 2, continue; end
    t = sort(t);
    y = (1:numel(t))' / numel(t);
    lw = cfg.cdf_lw;
    if strcmp(keys{k},'cn'), lw = cfg.cdf_cn_lw; end
    stairs(ax, t, y, 'LineWidth', lw, 'Color', color_(keys{k},cfg), 'HandleVisibility','off');
end

set(ax,'YLim',[0 1]);
if cfg.use_logx_timing, set(ax,'XScale','log'); end
end

function plot_viol_cdf_signedlog_(ax, out, usePWA, cfg)
keys  = {'qp','nn','prj','cn'};
Vlist = {out.viol.qp(:), out.viol.nn(:), out.viol.prj(:), out.viol.cn(:)};
if usePWA
    keys  = [{'pwa'}, keys];
    Vlist = [{out.viol.pwa(:)}, Vlist];
end

for k = 1:numel(Vlist)
    v = Vlist{k};
    v = v(isfinite(v));
    if numel(v) < 2, continue; end
    x = signedlog10_(v, cfg.viol_v0);
    x = sort(x);
    y = (1:numel(x))' / numel(x);
    lw = cfg.cdf_lw;
    if strcmp(keys{k},'cn'), lw = cfg.cdf_cn_lw; end
    stairs(ax, x, y, 'LineWidth', lw, 'Color', color_(keys{k},cfg), 'HandleVisibility','off');
end

xline(ax, 0, '--', 'HandleVisibility','off');
xmark = signedlog10_(cfg.viol_mark, cfg.viol_v0);
xline(ax, xmark, '--', 'HandleVisibility','off');

set(ax,'YLim',[0 1]);
set_signedlog_xticks_(ax, cfg.viol_v0, cfg.viol_mark);
end

function plot_timing_summary_(ax, out, usePWA, cfg)
names = {'QP','PureNN','NN+Proj','CertNet'};
keys  = {'qp','nn','prj','cn'};
Tlist = {out.timing_us.qp(:), out.timing_us.nn(:), out.timing_us.prj(:), out.timing_us.cn(:)};
if usePWA
    names = [{'PWA'}, names];
    keys  = [{'pwa'}, keys];
    Tlist = [{out.timing_us.pwa(:)}, Tlist];
end

Q = nan(numel(Tlist),3); % [mean, p50, p99]
for k = 1:numel(Tlist)
    t = Tlist{k};
    t = t(isfinite(t));
    if isempty(t), continue; end
    Q(k,1) = mean(t);
    Q(k,2) = prctile(t,50);
    Q(k,3) = prctile(t,99);
end

hold(ax,'on');
y = (1:numel(names)).';

h_mean = 0.22;   % mean竖线半高（y轴单位）
lw_seg = 3.0;    % p50--p99横线
lw_mean = 0.8;   % mean粗竖线

for r = 1:numel(names)
    c = color_(keys{r},cfg);
    mu  = Q(r,1);
    p50 = Q(r,2);
    p99 = Q(r,3);
    if ~all(isfinite([mu p50 p99])), continue; end

    % p50 -- p99 区间横线
    plot(ax, [p50 p99], [y(r) y(r)], '-', 'Color', c, 'LineWidth', lw_seg, 'HandleVisibility','off');

    % mean 粗竖线（替换原来的圆点）
    plot(ax, [mu mu], [y(r)-h_mean y(r)+h_mean], '-', 'Color', c, 'LineWidth', lw_mean, 'HandleVisibility','off');
end

set(ax,'YDir','reverse','YTick',y,'YTickLabel',names,'TickLabelInterpreter','latex');
xlabel(ax,'runtime ($\mu\mathrm{s}$)','Interpreter','latex');
grid(ax,'on');

% ---- annotate as one pair: (mean,p99) ----
if cfg.annot_timing_vals
    xl = xlim(ax);
    xr = max(xl(2) - xl(1), eps);
    dx = 0.012 * xr;

    for r = 1:numel(names)
        mu  = Q(r,1);
        p50 = Q(r,2);
        p99 = Q(r,3);
        if ~all(isfinite([mu p50 p99])), continue; end
        c = color_(keys{r},cfg);

        txt_pair = sprintf('(%s,%s)', sprintf(cfg.annot_fmt, mu), sprintf(cfg.annot_fmt, p99));

        x_txt = p99 + dx;
        ha = 'left';
        if x_txt > xl(2) - 0.02*xr
            x_txt = p50 - dx;
            ha = 'right';
        end

        text(ax, x_txt, y(r), txt_pair, ...
            'Interpreter','none', ...
            'FontSize',cfg.annot_fs, ...
            'Color',c, ...
            'HorizontalAlignment',ha, ...
            'VerticalAlignment','middle', ...
            'Clipping','on');
    end
end
end

function plot_pareto_(ax, out, cfg)
methods = {'nn','prj','cn'};

for k = 1:numel(methods)
    m = methods{k};
    x = out.timing_us.(m)(:);
    y = out.mse.(m)(:);
    ok = isfinite(x) & isfinite(y);
    x = x(ok);
    y = y(ok);
    if isempty(x), continue; end
    if ~isempty(cfg.nu) && isfinite(cfg.nu), y = cfg.nu * y; end
    y = max(y, 1e-16);
    scatter(ax, x, y, cfg.pt_size, 'filled', 'MarkerFaceColor', color_(m,cfg), 'MarkerEdgeColor','none', 'HandleVisibility','off');
end

set(ax,'XScale','log');
if cfg.use_loglog_pareto, set(ax,'YScale','log'); end
ylabel(ax,'pointwise error','Interpreter','latex');
end

function c = color_(key,cfg)
k = lower(char(string(key)));
if strcmp(k,'qp') || strcmp(k,'opt')
    c = cfg.st.qp;
elseif strcmp(k,'nn')
    c = cfg.st.nn;
elseif strcmp(k,'prj') || strcmp(k,'nnp')
    c = cfg.st.prj;
elseif strcmp(k,'cn')
    c = cfg.st.cn;
elseif strcmp(k,'pwa')
    c = cfg.st.pwa;
else
    c = [0.2 0.2 0.2];
end
end

function x = signedlog10_(v, v0)
v = double(v);
x = sign(v) .* log10(1 + abs(v)./v0);
end

function set_signedlog_xticks_(ax, v0, mark)
ticks_raw = [-mark 0 mark];
xt = signedlog10_(ticks_raw, v0);
set(ax,'XTick',xt);

lbl = {sprintf('$-10^{%d}$', round(log10(mark))), '$0$', sprintf('$10^{%d}$', round(log10(mark)))}; %#ok<SPRINTFN>
set(ax,'XTickLabel',lbl,'TickLabelInterpreter','latex');
xtickangle(ax,0);
ax.TickLength = [0.02 0.02];
end

function add_side_method_legend_(fig, axAll, cfg)
% One-column side legend, centered in the left margin, with robust bounds checking.

keys  = {'pwa','qp','nn','prj','cn'};
names = {'PWA','QP','PureNN','NN+Proj','CertNet'};
nItem = numel(keys);

axAll = axAll(isgraphics(axAll));
if isempty(axAll), return; end

% ---- infer plot block bounds from axes ----
P = zeros(numel(axAll),4);
for i = 1:numel(axAll)
    axAll(i).Units = 'normalized';
    try
        P(i,:) = axAll(i).InnerPosition;
    catch
        P(i,:) = axAll(i).Position;
    end
end

xLeftTiles = min(P(:,1));
yBottomAll = min(P(:,2));
yTopAll    = max(P(:,2) + P(:,4));
yCenterAll = 0.5 * (yBottomAll + yTopAll);

% ---- left margin for legend ----
leftPad = 0.008;
gapToTiles = 0.008;
leftBandL = leftPad;
leftBandR = xLeftTiles - gapToTiles;

% fallback if too tight
minBandW = 0.075;
if leftBandR - leftBandL < minBandW
    leftBandR = xLeftTiles - gapToTiles;
    leftBandL = max(0.005, leftBandR - minBandW);
end

% clamp band into [0,1]
leftBandL = clamp_(leftBandL, 0.005, 0.95);
leftBandR = clamp_(leftBandR, leftBandL + 0.05, 0.98);

availW = leftBandR - leftBandL;

% ---- legend box geometry ----
titleH = 0.030;
itemH  = 0.00;
dy     = 0.12;
boxH_des = titleH + 0.01 + (nItem-1)*dy + itemH;

topMargin = 0.02;
botMargin = 0.02;
maxBoxH = 1 - topMargin - botMargin;
boxH = min(boxH_des, maxBoxH);

boxW_des = 0.125;
boxW = min(boxW_des, 0.96 * availW);
boxW = max(boxW, 0.060);

x0 = leftBandL + 0.5 * (availW - boxW);
y0 = yCenterAll - 0.5 * boxH;

x0 = clamp_(x0, 0.005, 0.995 - boxW);
y0 = clamp_(y0, 0.005, 0.995 - boxH);

% ---- inner layout ----
padL = 0.004;
tokenW = min(0.028, 0.32*boxW);
xLine0 = x0 + padL;
xLine1 = xLine0 + tokenW;
xText  = xLine1 + 0.006;
wText  = max(0.01, x0 + boxW - xText - 0.002);

yFirst = y0 + boxH - 0.018;

for i = 1:nItem
    y = yFirst - (i-1)*dy;

    if y < y0 + 0.010 || y > y0 + boxH - 0.005
        continue;
    end

    lw = cfg.cdf_lw;
    if strcmp(keys{i},'cn'), lw = cfg.cdf_cn_lw; end

    annotation(fig,'line', [xLine0 xLine1], [y y], 'Units','normalized', 'Color', color_(keys{i},cfg), 'LineWidth', lw);

    annotation(fig,'textbox', [xText, y-0.014, wText, 0.028], ...
        'String', names{i}, ...
        'Units','normalized', ...
        'EdgeColor','none', ...
        'BackgroundColor','none', ...
        'Margin',0, ...
        'HorizontalAlignment','left', ...
        'VerticalAlignment','middle', ...
        'Interpreter','none', ...
        'FontSize', cfg.leg_fs);
end
end

function v = clamp_(v, lo, hi)
v = min(max(v, lo), hi);
end