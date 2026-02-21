# certnet-control-sim

## Overview
This repository contains the MATLAB implementation of our certified executor / CertNet framework for hard-constrained control with deployable, predictable-latency execution.

The codebase includes:
- a reusable toolbox for certified library construction and CertNet execution,
- training and inference utilities,
- and reproducible experiments for three case studies:
  - mpQP benchmark,
  - control allocation (CA),
  - adaptive cruise control (ACC).

The framework is designed to decouple hard-constraint feasibility from performance learning:
offline, we compile and synthesize certified feasible candidate libraries; online, we execute a fixed-structure algebraic pipeline without iterative optimization.

---

## Repository contents
```text
.
├─ CertNet Toolbox/                         # Core toolbox for certified executor / CertNet
│  ├─ cert/                                 # Certified feasible library construction and querying
│  │  ├─ @Cert/
│  │  │  ├─ Cert.m
│  │  │  ├─ api_build_.m
│  │  │  ├─ api_build_.asv
│  │  │  ├─ api_check_cover_cacheAct_.m
│  │  │  ├─ api_supplement_cacheAct_.m
│  │  │  └─ api_vertices_.m
│  │  ├─ cfg/
│  │  │  └─ set_cert_default_cfg_.m
│  │  └─ query_cache/                       # Cached query structures for fast online lookup
│  │     ├─ cache_append_.m
│  │     ├─ cache_init_.m
│  │     └─ query_.m
│  │
│  ├─ cert-net/                             # CertNet executor and training/inference APIs
│  │  ├─ @Certnet/
│  │  │  ├─ Certnet.m
│  │  │  ├─ api_build_.m
│  │  │  ├─ api_forward_.m
│  │  │  ├─ api_train_.m
│  │  │  └─ api_train_.asv
│  │  ├─ cfg/
│  │  │  └─ set_certnet_cfg_default_.m
│  │  ├─ InterFcn/                          # Interface/export helpers
│  │  │  └─ export_phi_params_.m
│  │  ├─ cvxOpt/                            # Convex / simplex / Carathéodory utilities
│  │  │  ├─ carath_reduce_.m
│  │  │  ├─ convex_rep_ok_.m
│  │  │  ├─ proj_simplex_.m
│  │  │  └─ simplex_ls_.m
│  │  └─ utilFcn/                           # General utility functions
│  │     ├─ getfield_def_.m
│  │     ├─ norm_x_.m
│  │     ├─ simplex_cus.m
│  │     ├─ simplex_cus.asv
│  │     ├─ softplus_.m
│  │     └─ struct_merge_.m
│  │
│  └─ Experiments/                          # Reproducible experiment scripts and reports
│     ├─ sim_ACC/                           # Adaptive Cruise Control (ACC) case study
│     │  ├─ sim_ACC.mlx                     # Main ACC demo / experiment notebook
│     │  ├─ acc_test_closedloop_.m          # Closed-loop evaluation
│     │  ├─ acc_plot_.m                     # Plotting utilities
│     │  ├─ acc_report_.m                   # Summary/report generation
│     │  └─ Outputs/                        # ACC outputs (figures, logs, tables)
│     │
│     ├─ sim_CA/                            # Control Allocation (CA) case study
│     │  ├─ sim_CA.mlx                      # Main CA demo / experiment notebook
│     │  ├─ ca_test_sync_inject_.m          # Closed-loop / injection evaluation
│     │  ├─ ca_plot_.m                      # Plotting utilities
│     │  ├─ ca_report_.m                    # Summary/report generation
│     │  └─ Outputs/                        # CA outputs (figures, logs, tables)
│     │
│     ├─ sim_mpQP/                          # mpQP benchmark experiments
│     │  ├─ sim_mpqp.mlx                    # Main mpQP demo / experiment notebook
│     │  ├─ mpqp_make_problem_.m            # Problem generation
│     │  ├─ mpqp_build_baseline_.m          # Baseline construction (Opt / PWA / NN / NN+Proj)
│     │  ├─ mpqp_gen_trainingData.m         # Training data generation
│     │  ├─ mpqp_test_problem_.m            # Benchmark evaluation
│     │  ├─ mpqp_plot_problem2_.m           # Plotting / summary figures
│     │  ├─ mpqp_report_problem_.m          # Reporting utilities
│     │  └─ outputs/                        # mpQP outputs (figures, logs, tables)
│     │
│     └─ tmpFcns/                           # Temporary / helper functions for experiments
│        ├─ build_pureNN_.m
│        ├─ net_to_alg_.m
│        └─ pure_nn_forward_alg_.m
│
├─ Figures/                                 # Exported paper-ready figures
│  ├─ sim_ACC.pdf
│  ├─ sim_CA.pdf
│  └─ sim_mpQP.pdf
│
├─ ACC_vars_2026-02-20_101044.mat           # Saved ACC experiment variables/results
├─ CA_vars_2026-02-20_104948.mat            # Saved CA experiment variables/results
├─ MPQP_vars_2026-02-20_160236.mat          # Saved mpQP experiment variables/results
├─ untitled.mlx                             # Scratch notebook (optional; can be removed)
└─ README.md
