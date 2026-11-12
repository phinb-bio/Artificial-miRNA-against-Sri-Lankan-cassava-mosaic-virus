# amirna-slcmv-durability

**A durability-prioritised design pipeline for artificial microRNAs against
plant begomoviruses, applied to Sri Lankan cassava mosaic virus.**

[![Code: MIT](https://img.shields.io/badge/code-MIT-blue.svg)](LICENSE)
[![Data: CC BY 4.0](https://img.shields.io/badge/data-CC%20BY%204.0-lightgrey.svg)](LICENSE-DATA.md)
[![Tests](https://img.shields.io/badge/tests-206%20offline%20assertions-green.svg)](tests/)

This repository contains the complete analysis accompanying:

> **Entropy- and population-scale design of durability-prioritised artificial
> microRNAs against Sri Lankan cassava mosaic virus: a computational framework
> and its limits**
> Bang Phi Nguyen. Submitted to *Functional & Integrative Genomics*, 2026.
> DOI: *to be added on acceptance*

Archived release: *Zenodo DOI to be added*

---

## Table of contents

- [The problem](#the-problem)
- [What this pipeline does](#what-this-pipeline-does)
- [Headline results](#headline-results)
- [What did not work](#what-did-not-work)
- [Repository layout](#repository-layout)
- [Installation](#installation)
- [Reproducing the analysis](#reproducing-the-analysis)
- [Pipeline stages](#pipeline-stages)
- [Scoring definitions](#scoring-definitions)
- [Output tables](#output-tables)
- [Data provenance](#data-provenance)
- [Software versions](#software-versions)
- [Troubleshooting](#troubleshooting)
- [Licence](#licence)
- [Citation](#citation)

---

## The problem

Artificial microRNAs (amiRNAs) silence a target transcript by loading a
21-nucleotide guide into ARGONAUTE 1, which then cleaves any RNA with
sufficient complementarity. They are an attractive route to engineered virus
resistance in plants: the viral insert is short, so the transgenic footprint
is small and there is little opportunity for recombination between the
transgene and the challenging virus.

The difficulty is not obtaining resistance. It is keeping it.

Begomoviruses are single-stranded DNA viruses that accumulate substitutions at
rates comparable to RNA viruses — on the order of 10⁻⁴ to 10⁻³ substitutions
per site per year. Against a 21-nt target, a handful of substitutions in the
right positions abolishes cleavage. The field's existing design tools, WMD3
and P-SAMS, were built to silence *plant* genes, where there is no variable
pathogen population to consider. They optimise the thermodynamic and
positional properties of the small RNA itself and screen for host off-targets
against a single reference sequence. Applied to a rapidly evolving virus, they
say nothing about how long a construct will keep working.

In effect, the field optimises how well an amiRNA works on the day it is made,
and leaves how long it will keep working to chance.

## What this pipeline does

It brings population-scale evidence into the ranking, and keeps apart two
things that are usually summed into a single number:

| Score | Components | Purpose |
|---|---|---|
| **Durability Score (DS)** | conservation (Shannon entropy), population coverage, positionally weighted Escape Risk Index, synonymous escape room (*π*<sub>S</sub>), cross-target breadth | resistance to evolutionary escape |
| **Efficacy Score (ES)** | design-rule compliance, secondary-structure accessibility | expected silencing potency *now* |

They are kept apart for an empirical reason, not an aesthetic one. In the
hold-out experiments reported in the paper, the rule score predicted future
population coverage in the **wrong direction** (Spearman *ρ* between −0.245
and −0.289, consistently across both splits and both genome segments).
Summing it into a single composite would have concealed that.

Six components of the framework are, to our knowledge, new to amiRNA design:

1. **Escape Risk Index (ERI)** — minor-allele frequency weighted by position
   within the amiRNA, so that variation at the central cleavage positions
   counts far more than variation at the 3′ end.
2. ***π*<sub>S</sub> as escape room** — synonymous nucleotide diversity read
   directly, in place of *π*<sub>N</sub>/*π*<sub>S</sub>, which is undefined in
   most 21-nt windows.
3. **Redundancy-constrained set cover** — a multi-amiRNA cluster in which
   every record is covered at least *R* times, not merely once.
4. **Two-part escape simulation** — observed joint escape across cluster
   members, plus a forward model parameterised by published substitution rates.
5. **Recombination audit** — asks whether high-scoring targets inadvertently
   sit in recombination hotspots, reported as an enrichment ratio against the
   genome-wide background rather than as a bare fraction.
6. **Pair-table backbone embedding** — grafting into real plant precursors
   using the base-pair table of the native fold, which respects the two-
   nucleotide asymmetry of the miRNA/miRNA\* duplex.

We make no claim that the individual ingredients are novel in themselves;
set cover, for instance, has been used in mosaic antigen design. The
contribution is the transfer and integration of these methods into amiRNA
design, together with an honest test of whether the result predicts anything.

## Headline results

Analysis panel: **1046 curated begomovirus genome records**.

| Target | Role | Records | Years | Countries | Mean per-site entropy |
|---|---|---:|---|---:|---:|
| SLCMV DNA-A | design | 181 | 2008–2026 | 10 | 0.0270 bits |
| SLCMV DNA-B | design | 154 | 2008–2026 | 9 | 0.0257 bits |
| ICMV DNA-A | validation | 11 | 2008–2012 | 2 | — |
| ToLCNDV DNA-A | validation | 700 | 2004–2026 | 22 | 0.2100 bits |

- **SLCMV is remarkably conserved.** The longest run of columns with zero
  entropy across all 181 DNA-A records spans 40 nt at positions 1430–1469, in
  the *AC2*/*AC3* overlap. The highest-ranked candidate of the study sits
  inside it. By contrast the longest fully invariant run in ToLCNDV, sampled
  7.8-fold more diversely, is 6 nt.
- **11,002** 21-nt windows enumerated; the 600 lowest-entropy windows per
  target evaluated in full; **740** candidates generated, **283** passing all
  hard filters.
- ***π*<sub>S</sub> is usable where the ratio is not.** Interpretable in 86.5%
  of windows against 38.3% for *π*<sub>N</sub>/*π*<sub>S</sub>, and only weakly
  correlated with conservation (*ρ* = 0.302), so it adds information.
- **Redundancy is what changes the design.** Single-layer coverage of the
  design records is complete from the third cluster member; two-fold coverage
  requires all five.
- **Durability-aware selection picks different molecules.** The top 30 by DS
  and the top 30 by classical criteria overlap by only 11 (Jaccard 0.224) —
  yet none of the 30 classical picks fails the durability filters. The two
  approaches disagree about ranking, not about admissibility.
- **Targets are depleted, not enriched, in recombination hotspots**
  (enrichment ratios 0.905 and 0.695 against genome backgrounds of 64.0% and
  67.8%).
- **Backbone embedding is feasible**: 52 of 60 grafts accepted, retaining
  92.3% of native base pairs against 55.9% for mature-arm-only replacement.

## What did not work

This section exists so that nobody has to discover these by reading the code.
They are stated at the same prominence in the paper.

- **The composite score does not yet rank candidates reliably.** Absolute
  transfer is excellent — candidates designed on pre-2018 records keep a median
  coverage of 1.0000 on records collected later — but that conclusion needs no
  score; it follows from choosing conserved regions at all. Rank transfer did
  not validate: in the temporal split DS was constant across retained
  candidates, so no rank correlation is defined; in the geographic split it was
  *ρ* = +0.189 for DNA-A and a significantly **negative** −0.139 for DNA-B.
- **The score saturates.** Population coverage has a standard deviation of
  exactly zero across passing candidates, so a term carrying 20% of the weight
  does no discriminating at all, and 67 candidates tie at the maximum. This is
  partly a property of the biology and partly self-inflicted by pre-filtering
  to the 600 lowest-entropy windows.
- **The retrospective joint-escape test has no power.** Zero joint escape is a
  consequence of the selection filter, not an independent finding: the expected
  count under independence is below one, which fails the paper's own power
  criterion. The only genuine out-of-sample escape figure is 2.86% for ToLCNDV.
- **The forward escape model is a point-substitution model.** Begomoviruses
  recombine, and SLCMV DNA-A is close to monopartite and can trans-replicate a
  heterologous DNA-B. Segment exchange could defeat several cluster members at
  once and is not modelled anywhere in this framework.
- **Candidates are not statistically independent.** The top ten occupy four
  distinct loci. *p*-values in the output tables are descriptive only.
- **Off-target screening is position-agnostic.** `bowtie -v 3` contradicts the
  positional thesis of the work itself; a plant target-prediction tool such as
  psRNATarget would be the correct instrument.

The score should be used as a **filter and a tie-breaker**, not as a
calibrated predictor, until resistance phenotypes exist to fit it against.

## Repository layout

```
amirna.sh                  single-file installer; embeds the whole source tree
run_all.sh                 stage orchestrator (--from / --to / --skip)
config/
  config.example.sh        copy to config.sh and set NCBI_EMAIL
  targets.tsv              target definitions and design/validation roles
scripts/                   14 pipeline stages (Bash)
  lib.sh                   shared functions, logging, parameter defaults
  py/                      27 Python modules doing the actual computation
R/
  00_load_data.R           read data/final into a single .rds
  01_figures.R             figures, Vietnamese labels
  01_figures_en.R          figures, English labels (used in the article)
  02_stats.R               descriptive statistics and tests
envs/amirna.yml            conda environment specification
tests/                     206-assertion offline suite + fake-binary shims
data/final/                all derived tables (34 files) + tool_versions.txt
results/figures/           figures, Vietnamese labels, 300 dpi
results/figures_en/        figures, English labels, 300 dpi
results/amirna_data.rds    serialised R object; enough to redraw every figure
MANIFEST.md                file counts and sizes
SHA256SUMS.txt             checksums; verify with `sha256sum -c`
```

Raw GenBank records are **not** included — see
[Data provenance](#data-provenance).

## Installation

Requires Linux or WSL2, `bash`, and conda or mamba. Roughly 6 GB of disk for
the environment and databases.

```bash
bash amirna.sh install      # unpack the source tree into $HOME/amirna_work
cd "$HOME/amirna_work"
cp config/config.example.sh config/config.sh
$EDITOR config/config.sh    # NCBI_EMAIL is required; NCBI_API_KEY is optional
bash amirna.sh setup        # create the conda environment
bash amirna.sh doctor       # check tools, RAM, disk and network reachability
```

`AMIR_DIR` overrides the working directory and `DB_ROOT` the location of large
databases (default `$HOME/amirna_db`). On WSL, keep both on the Linux
filesystem rather than under `/mnt/c` or `/mnt/e`: the Windows drive is mounted
through drvfs and is an order of magnitude slower for many small files.

`config/config.sh` is listed in `.gitignore` and is never committed: it holds a
personal contact e-mail that NCBI requires, and optionally an API key.

## Reproducing the analysis

**Everything, from scratch** (about two hours on four threads, plus download
time for 1046 genome records):

```bash
bash amirna.sh test         # 206 assertions, offline, synthetic data
bash amirna.sh run --bg     # full pipeline; logs to logs/run_*.log
bash amirna.sh status       # progress
bash amirna.sh rload        # load results into R, write results/*.rds
```

**A single stage, or a range** — every stage is idempotent, so a stage that
already has output is skipped and a failed run resumes cleanly:

```bash
bash run_all.sh --from 9 --to 11
bash run_all.sh --skip 06
```

**Figures only**, from the committed `.rds`, without re-running anything:

```bash
Rscript --vanilla R/01_figures_en.R .    # -> results/figures_en/
Rscript --vanilla R/01_figures.R .       # -> results/figures/
```

**Verify this archive is intact:**

```bash
sha256sum -c SHA256SUMS.txt
```

## Pipeline stages

| # | Stage | What it does |
|---:|---|---|
| 01 | `fetch` | retrieve GenBank records per target via NCBI `datasets` |
| 02 | `curate` | parse flat files; drop wrong segment, wrong length, duplicates, ambiguous sequences |
| 03 | `align` | MAFFT alignment per target; pick a low-gap reference |
| 04 | `windows` | per-site Shannon entropy, gap fraction, minor-allele frequency; enumerate 21-nt windows; `RNAplfold` accessibility |
| 05 | `design` | generate candidate amiRNAs for both strand orientations; score the six design rules; `RNAduplex` free energy |
| 06 | `offtarget` | screen against the cassava transcriptome with `bowtie -v 3` |
| 07 | `selection` | per-codon Nei–Gojobori *π*<sub>N</sub> and *π*<sub>S</sub>; aggregate per window |
| 08 | `final` | hard filters, Durability and Efficacy scores, component standard deviations |
| 09 | `cluster` | redundancy-constrained greedy set cover; cross-pairing exclusion |
| 10 | `validate` | temporal and geographic hold-out; rescore on training records only |
| 11 | `backbone` | graft into ath-MIR164b / ath-MIR171a / ath-MIR319a using the native pair table |
| 12 | `escape` | observed joint escape per segment; forward substitution model |
| 13 | `recomb` | four-gamete test, Hudson–Kaplan *R*<sub>min</sub>, permutation test, enrichment ratio |
| 14 | `benchmark` | durability ranking against classical ranking; Mann–Whitney *U* |

The canonical stage list lives in the `STEPS` array at the top of
`run_all.sh`.

## Scoring definitions

**Escape Risk Index.** For an amiRNA position *i* with non-reference allele
frequency *m*<sub>σ(i)</sub> at the corresponding reference position:

```
ERI = Σ wᵢ · m_σ(i)  /  Σ wᵢ
```

with *w* = 1.0 for positions 8–12 (central, where ARGONAUTE cleaves), 0.7 for
2–7 (seed), 0.5 for 13–16, and 0.2 for position 1 and 17–21. Because
begomoviruses are transcribed bidirectionally, the position map inverts between
strand orientations; both are evaluated separately throughout. Conflating them
silently reverses the weighting profile.

**Durability Score** — weights: conservation 0.25, coverage 0.20, escape
resistance 0.20, *π*<sub>S</sub> 0.12, breadth 0.10; rescaled to 0–100.

**Efficacy Score** — rule compliance 0.10, accessibility 0.15; used only to
break ties among candidates of equal DS.

**Hard filters** — no predicted host off-target, amiRNA/target duplex free
energy between −45 and −28 kcal mol⁻¹, rule score ≥ 0.5.

All weights and thresholds are parameters in `config/config.sh`, with defaults
in `scripts/lib.sh`. The standard deviation of every component across passing
candidates is written to `data/final/score_weights.tsv` so that
non-discriminating terms are visible rather than hidden.

## Output tables

Every column of every table is documented in
`data/final/data_dictionary.tsv`. The ones most likely to be of interest:

| File | Contents |
|---|---|
| `candidates_ranked.tsv` | all 740 candidates, every metric, pass/fail and reason |
| `top_candidates.tsv` | the leading candidates after filtering and tie-breaking |
| `score_weights.tsv` | component weights, standard deviations, tie count |
| `cluster_design.tsv` | the selected cluster, step by step, with cumulative coverage |
| `cluster_coverage_curve.tsv` | coverage as a function of cluster size |
| `escape_joint.tsv`, `escape_members.tsv` | observed escape per site and per segment |
| `escape_forward.tsv` | forward model across substitution rates and horizons |
| `recomb_summary.tsv` | *R*<sub>min</sub>, incompatible pairs, permutation *p*, enrichment |
| `constructs.tsv` | all 60 backbone grafts, both embedding strategies |
| `benchmark_summary.tsv` | durability versus classical selection |
| `validation_*_by_target.tsv` | hold-out results, temporal and geographic |
| `supplementary_S1_accessions.tsv` | the 1046 accessions with host, country, date |
| `tool_versions.txt` | exact versions used for the published run |

## Data provenance

The genome sequences analysed are public GenBank records and are **not**
redistributed here, for two reasons: they are 18 MB of data that stage 01
re-downloads in minutes, and NCBI's own terms govern their redistribution. The
accession list needed to retrieve them is
`data/final/supplementary_S1_accessions.tsv`.

The host transcriptome used for off-target screening is NCBI assembly
**GCF_001659605.2** (*Manihot esculenta*), downloaded automatically by stage 06.

Two caveats a reader should carry into any reuse:

- **Conservation is a property of the sample as much as of the virus.** The
  SLCMV panel is dominated by Vietnam, Cambodia, Thailand, Laos and India. Much
  of the virus's range is absent, and entropy estimates will tighten as
  sampling deepens.
- **Two ToLCNDV records** (U15016.1, MZ209192.1) were not retained by MAFFT, so
  that alignment comprises 698 of the 700 curated sequences.

## Software versions

Recorded automatically for every run in `data/final/tool_versions.txt`. The
published analysis used:

| Tool | Version |
|---|---|
| Python | 3.11.18 |
| R | 4.6.2 |
| MAFFT | 7.526 |
| SeqKit | 2.14.0 |
| ViennaRNA | 2.6.4 |
| bowtie | 1.3.1 |
| NCBI datasets | 18.41.0 |
| Biopython | 1.88 |
| pandas | 3.1.1 |
| NumPy | 2.4.6 |

The R figure and statistics scripts use base R and `ape` only — no tidyverse
dependency — so they run on a minimal R installation.

## Troubleshooting

**`mamba` hangs at "Confirm changes".** mamba 2.x prompts interactively. The
setup stage passes `-y`, sets `CONDA_ALWAYS_YES` and `MAMBA_ALWAYS_YES`, and
redirects stdin from `/dev/null`; if you invoke conda by hand, do the same.

**Everything is slow under WSL.** The working directory or `DB_ROOT` is
probably on a Windows drive. Move both to the Linux filesystem. Allocate
enough RAM in `.wslconfig`; `bash amirna.sh wslconfig` prints a suggestion.

**`iqtree2: command not found`.** Some conda channels ship `iqtree3`. The
helper tries `iqtree3`, then `iqtree2`, then `iqtree`.

**R fails to read a table with non-ASCII characters.** Pass
`encoding="UTF-8"` to `read.delim`, not `fileEncoding`.

**A stage reports "already has output, skipping" when you wanted a rerun.**
Stages are idempotent by design. Move the stage's output directory aside — the
pipeline never deletes anything — and rerun with `--from N`.

**Tests fail with "RNAfold: command not found".** The offline suite uses
deterministic fake binaries in `tests/fakebin/`, which must be on `PATH`;
`bash amirna.sh test` handles this. Running the test scripts directly does not.

## Licence

| Component | Licence |
|---|---|
| Source code (`scripts/`, `R/`, `tests/`, `run_all.sh`, `amirna.sh`) | MIT — see [LICENSE](LICENSE) |
| Derived tables, figures, `.rds` | CC BY 4.0 — see [LICENSE-DATA.md](LICENSE-DATA.md) |
| Genome sequences | not redistributed; NCBI terms apply |

## Citation

Machine-readable metadata is in [`CITATION.cff`](CITATION.cff). Please cite
both the software archive and the article:

> Nguyen BP (2026) Entropy- and population-scale design of durability-
> prioritised artificial microRNAs against Sri Lankan cassava mosaic virus: a
> computational framework and its limits. *Functional & Integrative Genomics*.

> Nguyen BP (2026) amirna-slcmv-durability: a durability-prioritised design
> pipeline for artificial microRNAs against begomoviruses. Zenodo.

## Contact

Bang Phi Nguyen — Institute of Green and Sustainable Technology, and Faculty of
Natural Sciences, Thu Dau Mot University, Thu Dau Mot, Viet Nam.

Issues and pull requests are welcome through the repository's issue tracker.
