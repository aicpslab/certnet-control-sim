function out = struct_merge_(base, override)
    out = base;
    if isempty(override), return; end
    if ~isstruct(override), error('override must be a struct'); end

    fn = fieldnames(override);
    for k = 1:numel(fn)
        f = fn{k};
        v = override.(f);

        if isstruct(v) && isfield(out,f) && isstruct(out.(f))
            out.(f) = struct_merge_(out.(f), v);
        else
            out.(f) = v;
        end
    end
end