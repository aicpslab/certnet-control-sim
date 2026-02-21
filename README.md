# certnet-control-sim

## Overview

This repository provides the MATLAB implementation of our **certified executor / CertNet** framework for hard-constrained control with **deployable, predictable-latency execution**.

In hard-constrained control deployment, the key advantage of our framework is that it **decouples hard-feasibility guarantees from performance learning**. The certified executor enforces hard constraint satisfaction **structurally** at deployment time, while learning is used only to recover reference-policy performance **within a certified feasible family**. This yields **(i) feasibility by construction (R1)**, **(ii) competitive performance recovery (R2)**, and **(iii) a non-iterative fixed-graph execution path with predictable, budgetable evaluation cost (R3)**.

The repository includes:
- a reusable toolbox **`cnet-tb-v1`** for certified library construction and CertNet execution,
- and reproducible experiments for three case studies:
  - **mpQP benchmark**,
  - **control allocation (CA)**,
  - **adaptive cruise control (ACC)**.

The framework is designed to **decouple hard-constraint feasibility from performance learning**: offline, we synthesize certified feasible candidate libraries and train the learning component; online, we execute a fixed-structure algebraic pipeline without iterative optimization.

---

## Repository Structure

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
│
├─ Experiments/                             # Reproducible experiment scripts
│  ├─ sim_ACC/                              # Adaptive Cruise Control (ACC) case study
│  │  ├─ core/                              # ACC experiment functions (test/plot/report)
│  │  │  ├─ acc_plot_.m
│  │  │  ├─ acc_report_.m
│  │  │  └─ acc_test_closedloop_.m
│  │  └─ sim_ACC.mlx                        # Main ACC experiment script
│  │
│  ├─ sim_CA/                               # Control Allocation (CA) case study
│  │  ├─ core/                              # CA experiment functions (test/plot/report)
│  │  │  ├─ ca_plot_.m
│  │  │  ├─ ca_report_.m
│  │  │  └─ ca_test_sync_inject_.m
│  │  └─ sim_CA.mlx                         # Main CA experiment script
│  │
│  ├─ sim_mpQP/                             # mpQP benchmark experiments
│  │  ├─ core/                              # mpQP experiment functions (build/test/plot/report)
│  │  │  ├─ mpqp_build_baseline_.m
│  │  │  ├─ mpqp_gen_trainingData.m
│  │  │  ├─ mpqp_make_problem_.m
│  │  │  ├─ mpqp_plot_.m
│  │  │  ├─ mpqp_report_problem_.m
│  │  │  └─ mpqp_test_problem_.m
│  │  └─ sim_mpqp.mlx                       # Main mpQP experiment script
│  │
│  └─ tmpFcns/                              # Shared temporary/helper functions for experiments
│     ├─ build_pureNN_.m
│     ├─ net_to_alg_.m
│     └─ pure_nn_forward_alg_.m
│
├─ Figures/                                 # Exported paper-ready figures (PDF/EPS) and README previews (PNG)
│  ├─ sim_ACC.pdf
│  ├─ sim_ACC.eps
│  ├─ sim_ACC.png
│  ├─ sim_CA.pdf
│  ├─ sim_CA.eps
│  ├─ sim_CA.png
│  ├─ sim_mpQP.pdf
│  ├─ sim_mpQP.eps
│  └─ sim_mpQP.png
│
├─ ACC_vars_2026-02-20_101044.mat           # Saved ACC experiment variables/results
├─ CA_vars_2026-02-20_104948.mat            # Saved CA experiment variables/results
├─ MPQP_vars_2026-02-20_160236.mat          # Saved mpQP experiment results
├─ LICENSE
└─ README.md
````

> **Notes**
>
> * This repository provides the toolbox implementation **`cnet-tb-v1`**, which fully realizes the framework and experiment pipeline used in the paper.
> * The folders `cvxOpt/` and `utilFcn/` contain supporting convex-geometry and general mathematical utilities used by the implementation. These are foundational building blocks and may be replaced by alternative implementations.

---

## Quick Start

1. Clone or download this repository and keep the folder structure unchanged.
2. Open MATLAB and set the current folder to the repository root.
3. Add the repository root and all subfolders to the MATLAB path.
4. Run the following live scripts to reproduce the reported results (figures, tables, and intermediate logs/process information):

   * `Experiments/sim_mpQP/sim_mpqp.mlx`
   * `Experiments/sim_CA/sim_CA.mlx`
   * `Experiments/sim_ACC/sim_ACC.mlx`

### Reproducing Figures/Reports from Saved Data (Optional)

If you only want to regenerate the reported figures/tables without rerunning full simulations:

1. Load the corresponding saved `.mat` file in MATLAB (e.g., `MPQP_vars_*.mat`, `CA_vars_*.mat`, `ACC_vars_*.mat`).
2. Run the associated `report` and `plot` functions in the corresponding experiment `core/` folder.

> **Notes**
>
> * This repository includes saved simulation data used in the paper, containing the key parameters and baseline outputs needed for reproduction.
> * Full simulation runs save timestamped files automatically, so the paper snapshots are not overwritten.
> * Figures are exported in **PDF**, **EPS**, and **PNG**:
>
>   * **PDF / EPS** for paper-quality use,
>   * **PNG** for direct preview in GitHub README.

---

## Tested Environment

The code has been tested with the following environment:

* **OS:** Windows 11
* **CPU:** 11th Gen Intel(R) Core(TM) i7-11850H @ 2.50GHz
* **MATLAB:** R2025a (25.1.0.2943329)
* **Solvers/Libraries:** MOSEK 11.0.27; YALMIP 20250626; MPT3 3.2.1
* MATLAB product dependencies are not enumerated here for brevity; missing products will be reported at runtime when executing the provided live scripts/models.

> **Note**
>
> * MOSEK requires a valid license.

---

## Features and Experimental Highlights

> **GitHub preview note:** GitHub does not render PDF/EPS figures inline in README.  
> This repository therefore includes **PNG preview images** in `Figures/` for direct viewing, while **PDF/EPS** versions are kept as paper-ready exports.

### 1) mpQP Benchmark: Deployment Trade-offs Under Controlled Scaling

**Highlight**  
The mpQP benchmark provides a controlled setting to compare deployment trade-offs across **QP / PWA / PureNN / NN+Proj / CertNet**. It highlights that **CertNet preserves hard-feasibility (up to numerical tolerance) while significantly reducing online latency**, including tail latency, and remains deployable when explicit PWA compilation becomes unavailable.

**Evidence**
- **S1:** CertNet achieves **125.6 / 114.1 / 333.5 μs** (mean / p50 / p99), with **0.00%** hard-feasibility violation rate and **13.43×** mean-latency speedup over QP.
- **S2:** CertNet achieves **196.4 / 178.3 / 465.8 μs** (mean / p50 / p99), with **0.00%** hard-feasibility violation rate and **8.76×** mean-latency speedup over QP.
- **PWA availability:** PWA compiles for **S1** (full/active regions: **5899 / 1815**) but is **unavailable for S2** under the same offline compilation budget (timeout).
- **Certified library footprint (offline):**
  - S1: `n_{LFull}/n_{LAct} = 148 / 105`
  - S2: `n_{LFull}/n_{LAct} = 773 / 530`

**Artifacts included**
- Diagnostic figure: runtime CDF, violation CDF, timing summary, and runtime–error trade-off  
- Aggregate performance table (timing / feasibility / fidelity)  
- Offline deployability scale summary (PWA availability and library sizes)

<p align="center">
  <img src="Figures/sim_mpQP.png" width="900" alt="mpQP diagnostics: runtime CDF, violation CDF, timing summary, and runtime-error trade-off"><br>
  <b>mpQP diagnostics (S1/S2): runtime CDF, violation CDF, timing summary, and runtime–error trade-off</b>
</p>

**Aggregate result table (paper values)**

| Group | Method      | mean (μs) |  p50 (μs) |  p99 (μs) | Speedup (mean) | Max viol. | Viol. rate | u-MSE mean | u-MSE p95 |
| ----- | ----------- | --------: | --------: | --------: | -------------: | --------: | ---------: | ---------: | --------: |
| S1    | QP          |    1579.2 |    1466.8 |    2820.2 |           1.00 |   1.26e-8 |      0.00% |        --- |       --- |
| S1    | PWA         |     182.5 |     157.8 |     627.1 |           9.40 |  1.82e-14 |      0.00% |   5.58e-10 |  1.34e-12 |
| S1    | PureNN      |      24.6 |      21.6 |      80.6 |          68.81 |   2.64e-1 |     25.80% |    8.79e-3 |   2.78e-2 |
| S1    | NN+Proj     |    1212.3 |    1101.0 |    2338.7 |           1.34 |  4.67e-13 |      0.00% |    8.13e-3 |   2.65e-2 |
| S1    | **CertNet** | **125.6** | **114.1** | **333.5** |      **13.43** |   3.28e-8 |  **0.00%** |    1.03e-2 |   3.23e-2 |
| S2    | QP          |    1632.5 |    1525.8 |    2756.5 |           1.00 |   1.20e-8 |      0.00% |        --- |       --- |
| S2    | PureNN      |      25.5 |      22.9 |      73.0 |          68.75 |   6.81e-1 |     53.78% |    3.25e-2 |   1.02e-1 |
| S2    | NN+Proj     |    1160.5 |    1064.8 |    2181.5 |           1.43 |   2.88e-9 |      0.00% |    2.92e-2 |   9.77e-2 |
| S2    | **CertNet** | **196.4** | **178.3** | **465.8** |       **8.76** |   1.19e-7 |  **0.00%** |    4.15e-2 |   1.42e-1 |

---

### 2) Control Allocation (CA): Deadline-Aware Closed-Loop Deployment (Hold-on-Timeout)

**Highlight**  
The CA case emphasizes **real-time execution semantics** rather than timing alone. Under a fixed sampling deadline, any over-budget computation triggers a **hold action** (no command update). This makes runtime tails directly impact closed-loop performance. In this setting, **CertNet preserves hard feasibility while keeping runtime tails below the sampling budget**, yielding robust deploy-time behavior.

**Evidence (CA, \(T_s = 1000\,\mu s\))**
- **CertNet:** **217.2 / 189.4 / 680.8 μs** (mean / p50 / p99), **0.00% timeout rate**, **0.00%** hard-feasibility violation rate
- **NN+Proj:** **1271.2 / 1099.4 / 3590.1 μs**, **56.60% timeout rate**
- **Opt:** **1521.9 / 1326.3 / 4142.6 μs**, **100.00% timeout rate** under the same deploy-time deadline semantics
- **PureNN:** low latency, but **14.80%** hard-feasibility violation rate

**Artifacts included**
- Closed-loop trajectory figure under deadline execution (hold-on-timeout semantics)
- Aggregate table (timing / timeout / feasibility / tracking metric)
- Optional “ideal Opt” / oracle reference trajectory (timing ignored) for reference-quality comparison

<p align="center">
  <img src="Figures/sim_CA.png" width="720" alt="CA closed-loop trajectories under hold-on-timeout semantics"><br>
  <b>Control Allocation (CA): closed-loop trajectories under deadline (hold-on-timeout) execution</b>
</p>

---

### 3) Adaptive Cruise Control (ACC): CLF/CBF-Style Safety Filtering with Timing-Only Runtime Evaluation

**Highlight**  
The ACC benchmark evaluates a safety-critical CLF/CBF-style filtering setup, with hard constraints including input bounds, safety constraints, and one-step state bounds. Runtime is measured under representative deploy-time inputs but **not injected into the state update** (timing-only protocol), avoiding platform-specific delay/jitter assumptions. In this setting, **CertNet matches feasible baselines in control performance while substantially reducing runtime**.

**Evidence (ACC, \(T_s = 20\,ms\))**
- **CertNet:** **81.2 / 72.1 / 168.2 μs** (mean / p50 / p99), **0.00%** hard-feasibility violation rate, mean performance matches feasible baselines (≈ **1.65e1**)
- **Opt:** **897.3 / 859.1 / 1425.4 μs**
- **NN+Proj:** **800.6 / 812.7 / 1449.4 μs**
- **PureNN:** low latency, but **66.27%** hard-feasibility violation rate

**Artifacts included**
- Closed-loop trajectory figure (speed / acceleration / safety margin)
- Aggregate table (timing / feasibility / performance)
- Timing statistics collected on representative closed-loop inputs

<p align="center">
  <img src="Figures/sim_ACC.png" width="720" alt="ACC closed-loop trajectories and safety margin"><br>
  <b>Adaptive Cruise Control (ACC): closed-loop speed, acceleration, and safety margin under timing-only evaluation</b>
</p>

---

### 4) Closed-Loop Aggregate Table (CA + ACC, paper values)

| Group | Method      | mean (μs) |  p50 (μs) |  p99 (μs) | Speedup (mean) | Timeout rate (CA) | Max viol. | Viol. rate | Performance (mean) |
| ----- | ----------- | --------: | --------: | --------: | -------------: | ----------------: | --------: | ---------: | -----------------: |
| CA    | Opt         |    1521.9 |    1326.3 |    4142.6 |           1.00 |           100.00% |  -1.00e-1 |      0.00% |            9.81e-1 |
| CA    | PureNN      |      27.9 |      23.6 |     105.4 |          54.55 |             0.00% |   6.38e-3 |     14.80% |            8.53e-2 |
| CA    | NN+Proj     |    1271.2 |    1099.4 |    3590.1 |           1.20 |            56.60% |   2.20e-8 |      0.00% |            3.41e-1 |
| CA    | **CertNet** | **217.2** | **189.4** | **680.8** |       **7.01** |         **0.00%** |  -7.14e-3 |  **0.00%** |        **1.17e-4** |
| ACC   | Opt         |     897.3 |     859.1 |    1425.4 |           1.00 |               --- |  7.11e-15 |      0.00% |             1.65e1 |
| ACC   | PureNN      |      17.7 |      15.6 |      37.8 |          50.69 |               --- |    1.09e2 |     66.27% |             2.27e0 |
| ACC   | NN+Proj     |     800.6 |     812.7 |    1449.4 |           1.12 |               --- |   3.36e-6 |      0.00% |             1.65e1 |
| ACC   | **CertNet** |  **81.2** |  **72.1** | **168.2** |      **11.05** |               --- |   1.06e-9 |  **0.00%** |         **1.65e1** |

---

### 5) Reproducibility Assets Included

This repository includes both the **method implementation** and the **reproducibility artifacts** used for the paper:

- **Reusable toolbox**
  - `cnet-tb-v1/cert/`: certified feasible library construction and querying
  - `cnet-tb-v1/cert-net/`: CertNet executor, training, and inference APIs
- **Experiment scripts**
  - `Experiments/sim_mpQP/sim_mpqp.mlx`
  - `Experiments/sim_CA/sim_CA.mlx`
  - `Experiments/sim_ACC/sim_ACC.mlx`
- **Saved experiment data (`*.mat`)**
  - Includes the key variables/outputs needed to regenerate reported figures and tables
  - Timestamped saving prevents overwriting paper-result snapshots
- **Figure exports**
  - **PDF / EPS**: paper-ready vector outputs
  - **PNG**: GitHub/README preview images

> To regenerate the reported figures/tables without rerunning the full simulations, load the corresponding saved `.mat` file and run the associated `report` / `plot` functions in each experiment `core/` folder.

---

## Citation

If you use this repository in your research, please cite the corresponding paper (citation entry to be added upon publication).

---

## License

This project is released under the license included in this repository (see `LICENSE`).

---

## Contact

For questions or issues, please open a GitHub issue or contact the authors.
