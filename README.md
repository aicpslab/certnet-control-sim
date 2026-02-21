# certnet-control-sim

## Overview
This repository contains the MATLAB implementation of our certified executor / CertNet framework for hard-constrained control with deployable, predictable-latency execution.

The codebase includes:
- a reusable toolbox **`cnet-tb-v1`** for certified library construction and CertNet execution,
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
├─ cnet-tb-v1/                              # Core toolbox for certified executor / CertNet
│  ├─ cert/                                 # Certified feasible library construction and querying
│  │  ├─ @Cert/
│  │  │  ├─ Cert.m
│  │  │  ├─ api_build_.m
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
│  │  │  └─ api_train_.m
│  │  ├─ cfg/
│  │  │  └─ set_certnet_cfg_default_.m
│  │  ├─ InterFcn/                          # Interface/export helpers
│  │  │  └─ export_phi_params_.m
│  │  ├─ cvxOpt/                            # Convex/simplex/Carathéodory utilities
│  │  │  ├─ carath_reduce_.m
│  │  │  ├─ convex_rep_ok_.m
│  │  │  ├─ proj_simplex_.m
│  │  │  └─ simplex_ls_.m
│  │  └─ utilFcn/                           # General utility functions
│  │     ├─ getfield_def_.m
│  │     ├─ norm_x_.m
│  │     ├─ simplex_cus.m
│  │     ├─ softplus_.m
│  │     └─ struct_merge_.m
│  │
│  └─ Experiments/                          # Reproducible experiment scripts
│     ├─ sim_ACC/                           # Adaptive Cruise Control (ACC) case study
│     │  ├─ core/                           # ACC experiment functions (test/plot/report)
│     │  │  ├─ acc_plot_.m
│     │  │  ├─ acc_report_.m
│     │  │  └─ acc_test_closedloop_.m
│     │  └─ sim_ACC.mlx                     # Main ACC experiment script
│     │
│     ├─ sim_CA/                            # Control Allocation (CA) case study
│     │  ├─ core/                           # CA experiment functions (test/plot/report)
│     │  │  ├─ ca_plot_.m
│     │  │  ├─ ca_report_.m
│     │  │  └─ ca_test_sync_inject_.m
│     │  └─ sim_CA.mlx                      # Main CA experiment script
│     │
│     ├─ sim_mpQP/                          # mpQP benchmark experiments
│     │  ├─ core/                           # mpQP experiment functions (build/test/plot/report)
│     │  │  ├─ mpqp_build_baseline_.m
│     │  │  ├─ mpqp_gen_trainingData.m
│     │  │  ├─ mpqp_make_problem_.m
│     │  │  ├─ mpqp_plot_problem2_.m
│     │  │  ├─ mpqp_report_problem_.m
│     │  │  └─ mpqp_test_problem_.m
│     │  └─ sim_mpqp.mlx                    # Main mpQP experiment script
│     │
│     └─ tmpFcns/                           # Shared temporary/helper functions for experiments
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
├─ MPQP_vars_2026-02-20_160236.mat          # Saved mpQP experiment results
└─ README.md
```

> **Notes**
> - This repository provides our toolbox implementation, **`cnet-tb-v1`**, which fully realizes the framework and experimental pipeline presented in the paper.
> - The toolbox includes the main certified-library and CertNet components, as well as the experiment modules used to reproduce the reported results.
> - The folders `cvxOpt/` and `utilFcn/` contain supporting convex-geometry and basic mathematical utilities used by the implementation. These functions serve as foundational building blocks, but they are not unique to the method and may be replaced by improved implementations or alternative computational pipelines.

---
## Quick start

1. Download or clone this repository, and keep the folder structure unchanged.
2. Open MATLAB and set the current folder to the repository root.
3. Add the repository root and all subfolders to the MATLAB path.
4. Run the following three live scripts to reproduce all results reported in the paper (including figures, tables, and intermediate logs/process information):
   * `cnet-tb-v1/Experiments/sim_mpQP/sim_mpqp.mlx`
   * `cnet-tb-v1/Experiments/sim_CA/sim_CA.mlx`
   * `cnet-tb-v1/Experiments/sim_ACC/sim_ACC.mlx`
  
### Reproducing figures/reports from saved data (optional)

If you only want to reproduce the reported figures/tables without rerunning the full simulations:

1. Load the corresponding saved `.mat` file in MATLAB (e.g., `MPQP_vars_*.mat`, `CA_vars_*.mat`, `ACC_vars_*.mat`).
2. Run the associated `report` and `plot` functions in the corresponding experiment `core/` folder.

> **Notes**
> * This repository includes saved simulation data used in the paper, containing the required parameters and baseline outputs for reproduction.
> * Full simulation runs automatically save data with timestamped filenames, so the saved data used in the paper are not overwritten.
> * Exported paper-ready figures are saved to `Figures/`.

**Environment (reproducibility).**  
- **OS:** Windows 11  
- **CPU:** 11th Gen Intel(R) Core(TM) i7-11850H @ 2.50GHz  
- **MATLAB:** R2025a (25.1.0.2943329)  
- **Solvers/Libraries:** MOSEK 11.0.27; YALMIP 20250626; MPT3 3.2.1
- MATLAB toolboxes: omitted for brevity (MATLAB will report any missing product dependencies at runtime).

## Features

- **Certified hard-feasibility by construction (R1)**
  - `CertNet` enforces the hard-constraint interface structurally through certified library query + mixing, rather than relying on unconstrained regression.
  - In the reported experiments (mpQP, CA, ACC), `CertNet` achieves **0% hard-constraint violation rate** up to numerical tolerance, while `PureNN` shows nontrivial violation rates.

- **Competitive performance within the feasible family (R2)**
  - The framework decouples feasibility from learning: feasibility is guaranteed by the executor structure, while learning is used to improve performance inside the certified feasible family.
  - In mpQP, `CertNet` achieves competitive fidelity to the QP teacher (low \(u\)-MSE among feasible methods).
  - In CA/ACC closed-loop tests, `CertNet` matches or outperforms feasible baselines in the reported task metrics under the same deploy-time interface.

- **Low-latency deployable execution (R3)**
  - Online execution uses a fixed-structure algebraic pipeline (query + score + simplex-style mixing) with no online iterative optimization in the deployed `CertNet` path.
  - Across all three case studies, `CertNet` consistently reduces runtime (mean / p50 / p99) relative to online optimization and NN+projection baselines, including tail latency.

- **Three reproducible case studies**
  - **mpQP benchmark:** controlled scaling study, with explicit PWA comparison when available.
  - **CA (Control Allocation):** deadline-aware evaluation (hold-on-timeout), showing the impact of runtime tails on closed-loop performance.
  - **ACC (CLF/CBF-style safety filtering):** safety-critical feasibility under a timing-only protocol, with `CertNet` matching feasible-teacher performance at much lower runtime.

- **Reusable toolbox implementation (`cnet-tb-v1`)**
  - Includes the main certified-library and CertNet components (`cert/`, `cert-net/`) used in the paper.
  - Also provides supporting utilities (`cvxOpt/`, `utilFcn/`) and experiment modules for end-to-end reproduction.

- **Saved experiment data for reproduction**
  - Includes saved `.mat` result files used in the paper (mpQP / CA / ACC), containing the key parameters and baseline outputs needed for reproducing the reported figures and tables.
  - Full simulation runs save timestamped result files, so the paper data are not overwritten.

- **Paper-ready figures included**
  - Exported figures (`Figures/sim_mpQP.pdf`, `Figures/sim_CA.pdf`, `Figures/sim_ACC.pdf`) are included for quick inspection and direct comparison with the paper.
  - Plot/report utilities are also provided to regenerate figures/tables from saved data or fresh runs.

- **Offline/online deployment separation**
  - **Offline:** certified library compilation, active sublibrary synthesis, and deployable executor construction.
  - **Online:** fixed execution graph with predictable computational structure, suitable for latency-sensitive deployment.
