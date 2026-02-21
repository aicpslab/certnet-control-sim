classdef Cert < handle
    properties
        P
        nx
        nu
        law
        sc

        cfg
        cache               % complete cache
        cacheAct            % active cache

        opt_hot             % hot-path options (copied from cfg.opt by api_build_)

        xbuf                % double(nx,1)
        xbar                % double(nx,1)
    end

    methods
        function self = Cert(G,h,S,cfg)
            if nargin < 4, cfg = struct(); end
            api_build_(self, G, h, S, cfg);
        end

        function U = vertices(self, x, u)
            % trust boundary: normalize shapes once here
            if nargin < 3, u = []; end
            x = x(:);
            if ~isempty(u), u = u(:); end
            U = api_vertices_(self, x, u);
        end
    end
end
