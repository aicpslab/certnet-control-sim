% ========================================================================
% CertNet.m  (CLASS INTERFACE ONLY: build + infer + train dispatch) 
%
% This file keeps ONLY: class interface + key comments + thin dispatch. 
% All concrete implementations MUST live in the same directory: @CertNet/ 
% Suggested prefix sorting: init_/api_/inf_/trn_/util_/io_ 
%
% =============================== Pipeline ===============================
% CERT (fixed) -> PHI (learnable) -> POST (learnable)
%
%            ┌──────────────────────────────┐
% x_phys ───►│ (A) CERT  fixed / not learn  │───►  V(x) ∈ R^{K×nu}
%            │  V = cert.vertices(x_phys')  │
%            └──────────────────────────────┘
%                      ▲
%                      │  Note A 
%                      │   - cert consumes x_phys (physical state) ONLY
%                      │   - does NOT use x_mu/x_sig
%                      │   - no gradients through cert (numeric black-box)
%
% x_phys ───► (optional normalize) ───► x_phi ───► (B) PHI learnable ───► out = [t_raw; g_raw]
%          x_phi = (x_phys - x_mu)/x_sig        out_dim = (nu + 1)  (Scheme-1)
%
%   Note B: [x_mu, x_sig, use_norm] as a group 
%     - used ONLY to standardize x_phys for φ input
%     - x_mu : training-set mean, size (1×nx)
%     - x_sig: training-set std,  size (1×nx), with a small epsilon added
%
% out ───► split ───► t_raw, g_raw ───► process ───► t_dir, g
%           if nu==1: t_dir = t_raw
%           else:     t_dir = t_raw / (||t_raw|| + t_norm_eps)   (optional via use_t_norm)
%
%   Note C: [nu, t_norm_eps, use_t_norm] as a group 
%     - nu==1: DO NOT normalize t (otherwise t ≈ sign(t_raw) and capacity collapses)
%     - nu>1 : normalization improves identifiability of tau (often helps)
%     - t_norm_eps prevents division by ~0 when ||t_raw|| is small
%
% (V, t_dir, g, tau) ───► (C) POST ───► z ───► softmax ───► λ ───► u = V'λ
%             s = V*t_dir
%             z = (g / tau) * s     (Scheme-1: g is an amplitude gate)
%
%   Note D: [tau_floor, tau, inv_tau] as a group 
%     - training: tau = exp(tau_log) + tau_floor  (guarantees tau > 0)
%     - inference: use numeric tau (optionally cache inv_tau = 1/tau)
%     - tau_floor lower-bounds tau to avoid tau→0 (over-sharp logits / overflow)
%
% Scheme-1 extras 
%   - g_floor : lower bound for g (keeps logits from dying)
%   - g_max   : optional cap (<=0 means no cap)
%
% Training vs Inference 
%   TRAIN: dlarray + dlnetwork live ONLY inside train() (no training states stored)
%   INFER: pure algebra using exported Ws/bs + numeric tau + cert.vertices
%
% ========================================================================
% Required method files in @CertNet/ 
%   init_build_.m            % constructor body: parse cfg + build phi + export Ws/bs
%   api_cert_forward_.m      % cert_forward() body: end-to-end inference timing blocks
%   api_train_.m             % train() body: end-to-end training loop (dlfeval, adamupdate, etc.)
%
% Typical internal helpers (also in @CertNet/) 
%   inf_norm_x_.m            % x_phys -> x_phi (phi input normalization only)
%   inf_phi_forward_fast_.m  % pure-algebra forward using exported Ws/bs
%   inf_split_tg_.m          % [t_raw;g_raw] -> (t_dir,g) with Scheme-1 processing
%   trn_loss_grads_.m        % dlfeval target: loss + grads
%   util_export_phi_params_.m, util_getfield_default_.m, util_softplus_stable_.m, ...
% ========================================================================

classdef Certnet < handle

    % =============================== State ==============================
    properties
        cert; nx; nu
        use_norm; x_mu; x_sig
        Ws; bs
        t_norm_eps
        phi

        % ---- Scheme-1 extras ----
        g_floor
        g_max
        use_t_norm

        % for training
        Vxs0
    end

    % ============================== Public API ==========================
    methods
        function self = Certnet(cert, cfg, nx)
            if nargin < 2, cfg = struct(); end
            if nargin < 3, nx  = [];      end
            api_build_(self, cert, cfg, nx); 
        end

        function y = cert_forward(self, x)
            y = api_forward_(self, x);                          % @CertNet/api_cert_forward_.m
        end

        function hist = train(self, X, Y, cfg)
            if nargin < 4, cfg = struct(); end
            hist = api_train_(self, X, Y, cfg);                               % @CertNet/api_train_.m
        end
    end
end
