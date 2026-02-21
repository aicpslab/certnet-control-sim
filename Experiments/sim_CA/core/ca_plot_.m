function ca_plot_(out, pack)
% ca_plot_ (single-column, 10pt, 3x1, xlabel only bottom; plot tracking target)
%
% Minimal edits requested:
%   - Shorter legend labels
%   - Legend: 3 columns, 9pt
%   - Add top/bottom whitespace
%   - Remove all titles
%   - Fix bottom x-label being clipped
%   - MarkerSize = 3 (including target)
%
% pack (optional):
%   .plot_mode    = 'preferred' | 'deadline' | 'oracle' | 'both'
%   .export   = false/true
%   .export_name  = 'sim_CA'
%   .outdir       = 'Figures'
%   .marker_every = [] (auto) or positive integer

% ---------------- defaults ----------------
if nargin < 2, pack = struct(); end
pack.plot_mode    = get_opt_(pack,'plot_mode','preferred');
pack.export   = get_opt_(pack,'export',false);
pack.export_name  = get_opt_(pack,'export_name','sim_CA');
pack.outdir       = get_opt_(pack,'outdir','Figures');
pack.marker_every = get_opt_(pack,'marker_every',[]);

% ---------------- fixed paper settings ----------------
fig_w_in = 3.4;
fig_h_in = 3.15;
fs = 10;

if ~exist(pack.outdir,'dir'), mkdir(pack.outdir); end

fig = figure(gcf); clf(fig);
set(fig,'Units','inches','Position',[1 1 fig_w_in fig_h_in],'Color','w','Renderer','painters');
set(fig,'PaperUnits','inches');
set(fig,'PaperPosition',[0 0 fig_w_in fig_h_in]);
set(fig,'PaperSize',[fig_w_in fig_h_in]);

% ---------------- time axis ----------------
Ts    = out.meta.Ts_us * 1e-6;
nTest = out.meta.nTest;
t     = (0:nTest-1).' * Ts;

% ---------------- marker stride ----------------
if isempty(pack.marker_every) || ~isscalar(pack.marker_every) || pack.marker_every <= 0
    mk_step = max(1, round(nTest/4));   % keep your current choice
else
    mk_step = max(1, round(pack.marker_every));
end
mk_base = 1:mk_step:nTest;

% ---------------- targets ----------------
WDtest = out.ref.WDtest;
assert(size(WDtest,1)==nTest && size(WDtest,2)==3, 'WDtest must be nTest x 3.');

haveUstar = isfield(out,'ref') && isfield(out.ref,'Ustar') && ~isempty(out.ref.Ustar) && size(out.ref.Ustar,1)==nTest;
haveB     = isfield(out,'ref') && isfield(out.ref,'B')     && ~isempty(out.ref.B)     && all(size(out.ref.B)==[3,6]);
haveWstar = haveUstar && haveB;
if haveWstar
    Wstar = (out.ref.B * out.ref.Ustar.').';
end

% ---------------- methods (fixed order) ----------------
keys  = {'Opt','NN','NNp','CN'};
names = {'Opt','NN','NN+Proj','CN'};   % shortened

% oracle availability
haveOracle = false(size(keys));
for j = 1:numel(keys)
    k = keys{j};
    haveOracle(j) = isfield(out,'oracle') && isfield(out.oracle,k) && isfield(out.oracle.(k),'w') && ~isempty(out.oracle.(k).w);
end

% ---------------- style map ----------------
st = struct();

st.Opt.color  = [0.35 0.35 0.35];
st.NN.color   = [0.12 0.44 0.70];
st.NNp.color  = [0.00 0.62 0.52];
st.CN.color   = [0.78 0.24 0.26];

st.Opt.lw  = 0.5;
st.NN.lw   = 0.5;
st.NNp.lw  = 0.5;
st.CN.lw   = 0.5;

st.Opt.mk  = 's';
st.NN.mk   = 'o';
st.NNp.mk  = '^';
st.CN.mk   = 'd';

st.Opt.ms  = 3;
st.NN.ms   = 3;
st.NNp.ms  = 3;
st.CN.ms   = 3;
tgt_ms     = 3;

% marker phase shifts (stagger markers to avoid overlap)
st.Opt.shift  = 0;
st.CN.shift   = round(mk_step/2);
st.NN.shift   = round(mk_step/3);
st.NNp.shift  = round(2*mk_step/3);
tgt_shift     = round(mk_step/4);

% ---------------- axes layout (more top/bottom whitespace) ----------------
pos = [ ...
    0.16 0.64 0.80 0.22; ...
    0.16 0.37 0.80 0.22; ...
    0.16 0.10 0.80 0.22];

ax = gobjects(3,1);
for i = 1:3
    ax(i) = subplot(3,1,i);
    set(ax(i),'Position',pos(i,:));
    hold(ax(i),'on'); grid(ax(i),'on');
end

yLab = {'$w_1$','$w_2$','$w_3$'};

% legend handles/labels (top axis only)
hLeg = gobjects(0,1);
labLeg = {};

% ---------------- plot ----------------
for ic = 1:3
    a = ax(ic);

    % target WDtest (solid black + markers)
    ht = plot(a, t, WDtest(:,ic), ...
        'k-', 'LineWidth',0.6, ...
        'Marker','x', 'MarkerSize',tgt_ms, ...
        'MarkerEdgeColor','k', 'MarkerFaceColor','none');

    idxT = mk_base + tgt_shift;
    idxT = idxT(idxT <= nTest);
    try, set(ht,'MarkerIndices',idxT); catch, end

    if ic == 1
        hLeg(end+1,1) = ht; %#ok<AGROW>
        labLeg{end+1,1} = 'tgt'; %#ok<AGROW>
    else
        set(ht,'HandleVisibility','off');
    end

    % optional: Wstar = B*u*_k (black dotted)
    if haveWstar
        hs = plot(a, t, Wstar(:,ic), 'k:', 'LineWidth',0.6);
        if ic == 1
            hLeg(end+1,1) = hs; %#ok<AGROW>
            labLeg{end+1,1} = '$Bu^\star$'; %#ok<AGROW>
        else
            set(hs,'HandleVisibility','off');
        end
    end

    % methods
    for j = 1:numel(keys)
        k  = keys{j};
        dn = names{j};

        srcList = pick_sources_(pack.plot_mode, haveOracle(j));

        for s = 1:numel(srcList)
            src = srcList{s};
            if strcmp(src,'deadline')
                W   = out.deadline.(k).w;
                lab = dn;
                ls  = '-';
            else
                W   = out.oracle.(k).w;
                lab = [dn '*'];    % shortened oracle tag
                ls  = '--';
            end

            if ndims(W)==3, W = squeeze(W); end
            if size(W,1)~=nTest, W = W(1:nTest,:); end

            h = plot(a, t, W(:,ic), 'LineStyle',ls, 'LineWidth',st.(k).lw, 'Color',st.(k).color);

            set(h,'Marker',st.(k).mk,'MarkerSize',st.(k).ms, ...
                'MarkerEdgeColor',st.(k).color,'MarkerFaceColor','none');

            idx = mk_base + st.(k).shift;
            idx = idx(idx <= nTest);
            try, set(h,'MarkerIndices',idx); catch, end

            if ic == 1
                hLeg(end+1,1) = h; %#ok<AGROW>
                labLeg{end+1,1} = lab; %#ok<AGROW>
            else
                set(h,'HandleVisibility','off');
            end
        end
    end

    ylabel(a, yLab{ic}, 'Interpreter','latex');
    xlim(a, [t(1), t(end)]);

    if ic < 3
        xlabel(a,'');
        set(a,'XTickLabel',[]);
    else
        % ---- FIX: move xlabel upward to avoid clipping in export ----
        hx = xlabel(a,'$t\,(\mathrm{s})$','Interpreter','latex');
        set(hx,'Units','normalized');
        hp = get(hx,'Position');
        hp(2) = -0.10;   % default is usually lower; moving up prevents clipping
        set(hx,'Position',hp);
        set(hx,'Clipping','off');
    end

    % remove titles (do nothing here on purpose)
    style_axes_(a, fs);
    tighten_axes_(a);
end

% ---------------- legend (top axis only) ----------------
% ---------------- legend (manual: above ax(1), not inside) ----------------
if ~isempty(hLeg)
    lgd = legend(ax(1), hLeg, labLeg, 'Interpreter','latex', 'Box','off');
    set(lgd,'FontSize',9,'LineWidth',0.6,'Color','white');
    set(lgd,'Orientation','horizontal');
    try, lgd.NumColumns = 5; catch, end
    try, lgd.ItemTokenSize = [10 8]; catch, end

    % ---- manual placement: directly above the first subplot ----
    p1 = get(ax(1),'Position');            % [x y w h] in normalized units
    lgd.Units = 'normalized';

    gap = 0.010;                           % vertical gap between ax(1) and legend
    hL  = 0.085;                           % legend height
    yL  = min(1 - hL - 0.005, p1(2) + p1(4) + gap);

    lgd.Position = [p1(1), yL, p1(3), hL]; % same width as ax(1)
end

% ---------------- export ----------------
if pack.export
    pdf_path = fullfile(pack.outdir, [pack.export_name '.pdf']);
    eps_path = fullfile(pack.outdir, [pack.export_name '.eps']);
    png_path = fullfile(pack.outdir, [pack.export_name '.png']);

    drawnow;  % ensure layout/text positions are finalized before printing

    print(fig, pdf_path, '-dpdf', '-painters');
    print(fig, eps_path, '-depsc2', '-painters');
    print(fig, png_path, '-dpng', '-r300');
    fprintf('[ca_plot_] saved: %s, %s, and %s\n', pdf_path, eps_path, png_path);
end

end

% ======================================================================
function v = get_opt_(s, f, v0)
if isfield(s,f) && ~isempty(s.(f)), v = s.(f); else, v = v0; end
end

function srcList = pick_sources_(mode, hasOracle)
mode = lower(string(mode));
if mode=="deadline"
    srcList = {'deadline'};
elseif mode=="oracle"
    if hasOracle, srcList = {'oracle'}; else, srcList = {}; end
elseif mode=="both"
    if hasOracle, srcList = {'deadline','oracle'}; else, srcList = {'deadline'}; end
else % preferred
    if hasOracle, srcList = {'oracle'}; else, srcList = {'deadline'}; end
end
end

function style_axes_(ax, fs)
set(ax,'FontSize',fs,'TickLabelInterpreter','latex','LineWidth',0.75,'Box','on');
end

function tighten_axes_(ax)
try, set(ax,'LooseInset',max(ax.TightInset, 0.01)); catch, end
end