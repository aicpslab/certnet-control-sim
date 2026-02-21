function [WsOut, bsOut] = export_phi_params_(net)

    L               = net.Learnables;                                       % table: Layer / Parameter / Value
    [WsOut, bsOut]  = deal({}, {});
    i               = 1;

    while true
        lname       = "fc" + string(i);
        iw          = find((L.Layer==lname) & (L.Parameter=="Weights"), 1);
        ib          = find((L.Layer==lname) & (L.Parameter=="Bias"),    1);
        if isempty(iw) || isempty(ib), break; end

        WsOut{end+1}= double(extractdata(L.Value{iw})); %#ok<AGROW>
        bsOut{end+1}= double(extractdata(L.Value{ib})); %#ok<AGROW>
        i           = i + 1;
    end
end
