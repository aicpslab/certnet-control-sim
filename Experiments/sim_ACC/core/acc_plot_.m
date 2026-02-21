function acc_plot_(out, pack)
% acc_plot_
% 2x2 layout:
%   (1) v_k (+ vdes, vL optional)
%   (2) u_k (+ bounds optional)
%   (3) h_k = D_k - tau v_k  (legend ONLY here)
%
% Change requested:
%   - ONLY change line colors
%   - add markers (MarkerSize=3, with sparse MarkerIndices)

    names = out.names; M = numel(names); nTest = out.nTest;
    [fig_w_in, fig_h_in, fs] = deal(3.4, 2.76, 10);

    outdir = 'Figures'; if isfield(pack,'outdir') && ~isempty(pack.outdir), outdir = pack.outdir; end
    base = 'sim_ACC'; if isfield(pack,'export_name') && ~isempty(pack.export_name), base = pack.export_name; end
    export_eps = false; if isfield(pack,'export_eps') && ~isempty(pack.export_eps), export_eps = logical(pack.export_eps); end
    if ~exist(outdir,'dir'), mkdir(outdir); end

    fig = figure(gcf); clf(fig);
    set(fig,'Units','inches','Position',[1 1 fig_w_in fig_h_in],'Color','w','Renderer','painters');
    set(fig,'PaperUnits','inches','PaperPosition',[0 0 fig_w_in fig_h_in],'PaperSize',[fig_w_in fig_h_in]);

    Ts = pack.Ts;
    t_state = (0:nTest)*Ts; t_step = (0:nTest-1)*Ts;

    haveVdes = isfield(pack,'VdesTest') && ~isempty(pack.VdesTest) && numel(pack.VdesTest)==nTest;
    haveVL = isfield(pack,'VLTest') && ~isempty(pack.VLTest) && numel(pack.VLTest)==nTest;

    tau = pack.tau;
    haveUbd = isfield(pack,'umin') && isfield(pack,'umax') && isscalar(pack.umin) && isscalar(pack.umax);
    if haveUbd, umin = pack.umin; umax = pack.umax; end

    v_ylim = pick_ylim_pack_(pack,'vmin','vmax',[15, 30]);
    hk_ylim = [-10, 60];
    if haveUbd, margin = 0.1*max(1,(umax-umin)); u_ylim = [umin-margin, umax+margin]; else, u_ylim = [-6, 3]; end

    posV = [0.14 0.63 0.34 0.30];
    posU = [0.14 0.18 0.34 0.30];
    posH = [0.56 0.18 0.39 0.75];

    axV = subplot(2,2,1); set(axV,'Position',posV); hold(axV,'on'); grid(axV,'on');
    axU = subplot(2,2,3); set(axU,'Position',posU); hold(axU,'on'); grid(axU,'on');
    axH = subplot(2,2,[2,4]); set(axH,'Position',posH); hold(axH,'on'); grid(axH,'on');

    % ---------------- marker stride (sparse) ----------------
    mk_step = max(1, round(nTest/3));
    mk_base = 1:mk_step:nTest;
    mk_base_state = 1:mk_step:(nTest+1);
    ms = 3; tgt_ms = 3;

    % ---------------- style per method name ----------------
    clr = cell(M,1); mk = cell(M,1); sh = zeros(M,1);
    for j = 1:M
        nm = string(names{j});
        if nm=="Opt"
            clr{j} = [0.35 0.35 0.35]; mk{j} = 's'; sh(j) = 0;
        elseif nm=="NN"
            clr{j} = [0.12 0.44 0.70]; mk{j} = 'o'; sh(j) = round(mk_step/3);
        elseif nm=="NN+Proj" || nm=="NN+P" || nm=="NN_Proj"
            clr{j} = [0.00 0.62 0.52]; mk{j} = '^'; sh(j) = round(2*mk_step/3);
        elseif nm=="CertNet"
            clr{j} = [0.78 0.24 0.26]; mk{j} = 'd'; sh(j) = round(mk_step/2);
        elseif nm=="CertNetRaw"
            clr{j} = [0.85 0.50 0.10]; mk{j} = 'v'; sh(j) = round(mk_step/4);
        else
            clr{j} = [0.10 0.10 0.10]; mk{j} = 'x'; sh(j) = round(3*mk_step/4);
        end
    end

    % ===================== v_k (add markers, set colors) =====================
    for j = 1:M
        hv = plot(axV, t_state, squeeze(out.xi_traj(:,2,j)), 'LineWidth',1.15, 'Color',clr{j}, 'Marker',mk{j}, 'MarkerSize',ms, 'MarkerFaceColor','none', 'MarkerEdgeColor',clr{j}, 'HandleVisibility','off');
        idx = mk_base_state + sh(j); idx = idx(idx <= (nTest+1));
        try, set(hv,'MarkerIndices',idx); catch, end
    end
    if haveVdes
        ht = plot(axV, t_step, pack.VdesTest(:), 'k--', 'LineWidth',0.75, 'Marker','x', 'MarkerSize',tgt_ms, 'MarkerFaceColor','none', 'HandleVisibility','off');
        idxT = mk_base + round(mk_step/4); idxT = idxT(idxT <= nTest);
        try, set(ht,'MarkerIndices',idxT); catch, end
    end
    if haveVL
        hl = plot(axV, t_step, pack.VLTest(:), 'k:', 'LineWidth',0.75, 'Marker','+', 'MarkerSize',tgt_ms, 'MarkerFaceColor','none', 'HandleVisibility','off');
        idxL = mk_base + round(mk_step/2); idxL = idxL(idxL <= nTest);
        try, set(hl,'MarkerIndices',idxL); catch, end
    end
    xlabel(axV,''); set(axV,'XTickLabel',[]);
    ylabel(axV,'$v_k\,(\mathrm{m/s})$','Interpreter','latex');
    title(axV,'$v_k$','Interpreter','latex');
    xlim(axV,[t_state(1), t_state(end)]); ylim(axV,v_ylim);

    % ===================== u_k (add markers, set colors) =====================
    U = out.u_traj;
    for j = 1:M
        hu = plot(axU, t_step, U(:,j), 'LineWidth',1.15, 'Color',clr{j}, 'Marker',mk{j}, 'MarkerSize',ms, 'MarkerFaceColor','none', 'MarkerEdgeColor',clr{j}, 'HandleVisibility','off');
        idx = mk_base + sh(j); idx = idx(idx <= nTest);
        try, set(hu,'MarkerIndices',idx); catch, end
    end
    if haveUbd
        yline(axU, umin,'k--','LineWidth',1.0,'HandleVisibility','off');
        yline(axU, umax,'k--','LineWidth',1.0,'HandleVisibility','off');
    end
    xlabel(axU,'$t\,(\mathrm{s})$','Interpreter','latex');
    ylabel(axU,'$u_k\,(\mathrm{m/s^2})$','Interpreter','latex');
    title(axU,'$u_k$','Interpreter','latex');
    xlim(axU,[t_step(1), t_step(end)]); ylim(axU,u_ylim);

    % ===================== h_k (legend here; add markers, set colors) =====================
    hLeg = gobjects(M,1);
    for j = 1:M
        Dk = squeeze(out.xi_traj(1:end-1,1,j));
        vk = squeeze(out.xi_traj(1:end-1,2,j));
        hk = Dk - tau*vk;
        hLeg(j) = plot(axH, t_step, hk, 'LineWidth',1.15, 'Color',clr{j}, 'Marker',mk{j}, 'MarkerSize',ms, 'MarkerFaceColor','none', 'MarkerEdgeColor',clr{j});
        idx = mk_base + sh(j); idx = idx(idx <= nTest);
        try, set(hLeg(j),'MarkerIndices',idx); catch, end
    end
    yline(axH,0,'k--','LineWidth',1.0,'HandleVisibility','off');
    xlabel(axH,'$t\,(\mathrm{s})$','Interpreter','latex');
    ylabel(axH,'$h_k$','Interpreter','latex');
    title(axH,'$h_k=D_k- \tau v_k$','Interpreter','latex');
    xlim(axH,[t_step(1), t_step(end)]); ylim(axH,hk_ylim);

    lgd = legend(axH, hLeg, names, 'Interpreter','latex','Location','northeast','Box','on');
    set(lgd,'FontSize',fs,'LineWidth',0.6,'Color','white');
    try, lgd.ItemTokenSize = [12 8]; catch, end

    style_axes_(axV,fs); style_axes_(axU,fs); style_axes_(axH,fs);
    tighten_axes_(axV); tighten_axes_(axU); tighten_axes_(axH);

    print(fig, fullfile(outdir,[base '.pdf']), '-dpdf', '-painters');
print(fig, fullfile(outdir,[base '.eps']), '-depsc', '-painters');
print(fig, fullfile(outdir,[base '.png']), '-dpng', '-r300');

    % -------------------- local helpers --------------------
    function y = pick_ylim_pack_(pack, loKey, hiKey, fallback)
        if isfield(pack,loKey) && isfield(pack,hiKey) && isscalar(pack.(loKey)) && isscalar(pack.(hiKey)) && pack.(hiKey) > pack.(loKey)
            lo = pack.(loKey); hi = pack.(hiKey); m = 0.05*max(1,(hi-lo)); y = [lo-m, hi+m];
        else
            y = fallback;
        end
    end

    function style_axes_(ax, fs)
        set(ax,'FontSize',fs,'TickLabelInterpreter','latex','LineWidth',0.75,'Box','on');
    end

    function tighten_axes_(ax)
        try, set(ax,'LooseInset',max(ax.TightInset, 0.01)); catch, end
    end
end
