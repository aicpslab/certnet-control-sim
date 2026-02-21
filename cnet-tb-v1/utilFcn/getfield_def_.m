function varargout = getfield_def_(s, varargin)
% getfield_def_  Get field(s) from struct with defaults (supports multiple).
%
% Usage:
%   v = getfield_def_(cfg, 'lr', 1e-3);
%   [epochs,batch,verbose] = getfield_def_(cfg, 'epochs',30, 'batch',256, 'verbose',1);
%
% Rule:
%   If field missing or empty => use default.

    if nargin < 3
        error('getfield_def_: need at least (s, name, def).');
    end
    if mod(numel(varargin), 2) ~= 0
        error('getfield_def_: arguments must be name/def pairs.');
    end

    nPairs = numel(varargin) / 2;

    % If caller requests 1 output but provides multiple pairs, that's ambiguous.
    if nargout ~= 0 && nargout ~= nPairs
        error('getfield_def_: number of outputs (%d) must match number of name/def pairs (%d).', nargout, nPairs);
    end

    % Allow s to be empty or non-struct => always return defaults
    isS = isstruct(s);

    for i = 1:nPairs
        name = varargin{2*i-1};
        def  = varargin{2*i};

        if isS && isfield(s, name) && ~isempty(s.(name))
            val = s.(name);
        else
            val = def;
        end

        varargout{i} = val; %#ok<AGROW>
    end
end
