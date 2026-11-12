#!/usr/bin/env bash
# =====================================================================
#  ghprep.sh — Dựng thư mục kho GitHub sạch từ cây làm việc
#
#  Dùng:  bash c ghprep [--with-manuscript] [--name TÊN_KHO]
#
#  Vì sao phải dựng thư mục riêng thay vì `git init` tại chỗ:
#  thư mục làm việc đang chứa 18 MB GenBank thô, 34 bản amirna_vNN.sh,
#  sáu thư mục _bak_*, log và tệp tạm. `git init` tại chỗ sẽ đưa tất cả
#  vào lịch sử vĩnh viễn ngay commit đầu tiên.
#
#  Script này CHỈ SAO CHÉP. Không sửa, không xoá gì trong cây làm việc.
#  Nếu github_repo/ đã tồn tại, nó được ĐỔI TÊN thành github_repo.bak_<ngày giờ>,
#  không bị xoá.
# =====================================================================
set -euo pipefail

W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$W"

WITH_MS=0
REPO_NAME="amirna-slcmv-durability"
while [ $# -gt 0 ]; do
  case "$1" in
    --with-manuscript) WITH_MS=1; shift ;;
    --name) REPO_NAME="${2:?thiếu tên kho}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "Tham số lạ: $1"; exit 2 ;;
  esac
done

OUT="$W/github_repo"
TS="$(date +%Y%m%d_%H%M%S)"

echo "=== Nguồn : $W"
echo "=== Đích  : $OUT"
echo "=== Kho   : $REPO_NAME"
echo

if [ -e "$OUT" ]; then
  mv "$OUT" "$OUT.bak_$TS"
  echo "[i] github_repo/ cũ đã được đổi tên thành github_repo.bak_$TS (không xoá)."
fi
mkdir -p "$OUT"

# ---------------------------------------------------------------------
# 1. Mã nguồn
# ---------------------------------------------------------------------
echo "[1/8] Sao chép mã nguồn…"
for d in scripts R envs tests; do
  [ -d "$W/$d" ] && cp -r "$W/$d" "$OUT/$d"
done
# Bỏ bytecode Python đi kèm
find "$OUT" -type d -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null || true
find "$OUT" -type f -name '*.pyc' -delete 2>/dev/null || true

[ -f "$W/run_all.sh" ] && cp "$W/run_all.sh" "$OUT/"

# Bộ cài một tệp: chỉ lấy bản hiện hành, KHÔNG lấy 34 bản amirna_vNN.sh
if [ -f "$W/amirna.sh" ]; then
  cp "$W/amirna.sh" "$OUT/amirna.sh"
  # Thư mục mặc định của bộ cài đang là ổ E: của máy này. Trong kho công
  # khai thì phải là một đường dẫn trung lập, khớp với hướng dẫn ở README.
  sed -i 's|/mnt/e/Ubuntu/work_amirna|$HOME/amirna_work|g' "$OUT/amirna.sh"
  echo "      amirna.sh ($(du -h "$OUT/amirna.sh" | cut -f1)) — bộ cài một tệp"
  echo "      (AMIR_DIR mặc định đổi thành \$HOME/amirna_work)"
fi

# ---------------------------------------------------------------------
# 2. Cấu hình — KHÔNG đưa config.sh thật lên
# ---------------------------------------------------------------------
echo "[2/8] Tạo config mẫu (xoá khoá API và email)…"
mkdir -p "$OUT/config"
for t in targets.tsv samples.tsv; do
  [ -f "$W/config/$t" ] && cp "$W/config/$t" "$OUT/config/$t"
done

EMAIL=""
if [ -f "$W/config/config.sh" ]; then
  EMAIL="$(sed -n 's/^NCBI_EMAIL="\([^"]*\)".*/\1/p' "$W/config/config.sh" | head -1)"
  sed -e 's/^\(NCBI_EMAIL=\).*/\1"your.email@example.org"   # BẮT BUỘC: NCBI yêu cầu email liên hệ/' \
      -e 's/^\(NCBI_API_KEY=\).*/\1""                        # tuỳ chọn: có khoá thì 10 req\/s thay vì 3/' \
      "$W/config/config.sh" > "$OUT/config/config.example.sh"
  echo "      config/config.example.sh đã tạo (config.sh thật KHÔNG được sao chép)"
else
  echo "      [!] không thấy config/config.sh — bỏ qua"
fi

# ---------------------------------------------------------------------
# 3. Bảng kết quả dẫn xuất
# ---------------------------------------------------------------------
echo "[3/8] Sao chép bảng kết quả…"
mkdir -p "$OUT/data/final"
cp "$W"/data/final/*.tsv "$OUT/data/final/" 2>/dev/null || true
cp "$W"/data/final/*.txt "$OUT/data/final/" 2>/dev/null || true
echo "      $(ls -1 "$OUT/data/final" | wc -l) tệp, $(du -sh "$OUT/data/final" | cut -f1)"

# ---------------------------------------------------------------------
# 4. Hình và đối tượng R
# ---------------------------------------------------------------------
echo "[4/8] Sao chép hình…"
mkdir -p "$OUT/results"
for d in figures figures_en; do
  [ -d "$W/results/$d" ] && cp -r "$W/results/$d" "$OUT/results/$d"
done
for f in amirna_data.rds descriptive_stats.tsv stats_tests.tsv; do
  [ -f "$W/results/$f" ] && cp "$W/results/$f" "$OUT/results/$f"
done
echo "      hình nhãn Việt: $(ls -1 "$OUT/results/figures" 2>/dev/null | wc -l) | nhãn Anh: $(ls -1 "$OUT/results/figures_en" 2>/dev/null | wc -l)"
echo "      $(du -sh "$OUT/results" | cut -f1) tổng cộng"

# ---------------------------------------------------------------------
# 5. Bản thảo (mặc định KHÔNG đưa lên)
# ---------------------------------------------------------------------
if [ "$WITH_MS" = "1" ]; then
  echo "[5/8] Sao chép bản thảo…"
  if [ -d "$W/manuscript" ]; then
    cp -r "$W/manuscript" "$OUT/manuscript"
    rm -f "$OUT/manuscript"/*.aux "$OUT/manuscript"/*.log \
          "$OUT/manuscript"/*.out "$OUT/manuscript"/*.blg 2>/dev/null || true
    if ! grep -q "and its" "$OUT/manuscript/main.tex" 2>/dev/null; then
      echo "      [!] CẢNH BÁO: main.tex trên đĩa có vẻ là bản TRƯỚC khi chỉnh theo"
      echo "          phản biện (tiêu đề cũ). Đồng bộ bản mới trước khi công bố."
    fi
  else
    echo "      [!] không thấy manuscript/ — bỏ qua"
  fi
else
  echo "[5/8] Bỏ qua bản thảo (mặc định)."
  echo "      Lý do: bài đang trong quá trình bình duyệt. Kho minh chứng cho"
  echo "      Code/Data availability chỉ cần mã + dữ liệu + hình. Muốn kèm thì"
  echo "      chạy lại với --with-manuscript."
fi

# ---------------------------------------------------------------------
# 6. Tệp mô tả kho
# ---------------------------------------------------------------------
echo "[6/8] Sinh README, LICENSE, CITATION.cff, .gitignore…"

cat > "$OUT/.gitignore" <<'GITIGNORE'
# --- Bí mật: không bao giờ commit -----------------------------------
config/config.sh
*.key
*.pem
.env

# --- Dữ liệu thô: tái tạo được bằng bước 01 của pipeline -------------
data/raw/
data/clean/
data/aln/
data/windows/
data/selection/
data/validation/
data/offtarget/
data/candidates/
data/recomb/
data/_bak_*/

# --- Tệp tạm, nhật ký, bản sao lưu -----------------------------------
logs/
tmp/
_tmp/
*.bak_*
amirna_v*.sh
claude_cmds/
mafft.*
prev_*/
data_mixed_*/
export/

# --- Sản phẩm biên dịch ----------------------------------------------
__pycache__/
*.pyc
*.aux
*.log
*.out
*.blg
*.synctex.gz
.Rhistory
.RData
GITIGNORE

cat > "$OUT/LICENSE" <<'MIT'
MIT License

Copyright (c) 2026 Bang Phi Nguyen

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
MIT

cat > "$OUT/LICENSE-DATA.md" <<'LICDATA'
# Licence for data and figures

The **source code** in this repository (`scripts/`, `R/`, `tests/`,
`run_all.sh`, `amirna.sh`) is released under the MIT Licence; see `LICENSE`.

The **derived data tables** (`data/final/`), **figures** (`results/figures/`,
`results/figures_en/`) and the serialised R object (`results/amirna_data.rds`)
are released under the
**Creative Commons Attribution 4.0 International Licence (CC BY 4.0)**:
<https://creativecommons.org/licenses/by/4.0/>

The underlying genome sequences are **not** redistributed here. They are
public records in NCBI GenBank and remain subject to NCBI's terms of use. The
accession list needed to retrieve them is
`data/final/supplementary_S1_accessions.tsv`, and step 01 of the pipeline
downloads them automatically.
LICDATA

cat > "$OUT/CITATION.cff" <<'CFF'
cff-version: 1.2.0
message: "If you use this software or the data tables in it, please cite both the software and the accompanying article."
title: "amirna-slcmv-durability: a durability-prioritised design pipeline for artificial microRNAs against begomoviruses"
abstract: >-
  An in-silico pipeline that brings population-scale evidence into artificial
  microRNA (amiRNA) design against plant begomoviruses. It computes per-site
  Shannon entropy over a curated genome panel, a positionally weighted Escape
  Risk Index, synonymous nucleotide diversity as a measure of available escape
  room, a redundancy-constrained multi-amiRNA set cover, retrospective and
  forward escape simulation, a recombination audit, precursor backbone
  embedding, and temporal and geographic hold-out validation. Applied to Sri
  Lankan cassava mosaic virus.
type: software
authors:
  - family-names: "Nguyen"
    given-names: "Bang Phi"
    affiliation: "Thu Dau Mot University, Thu Dau Mot, Viet Nam"
    # orcid: "https://orcid.org/0000-0000-0000-0000"   # ĐIỀN ORCID CỦA ANH
license: MIT
keywords:
  - artificial microRNA
  - amiRNA design
  - begomovirus
  - Sri Lankan cassava mosaic virus
  - cassava mosaic disease
  - escape mutation
  - resistance durability
  - plant virus resistance
  - bioinformatics
version: "1.0.0"
date-released: "2026-11-12"
# repository-code: "https://github.com/<USERNAME>/amirna-slcmv-durability"
# doi: "10.5281/zenodo.XXXXXXX"      # DOI khái niệm của Zenodo, điền sau bản phát hành đầu
preferred-citation:
  type: article
  title: "Entropy- and population-scale design of durability-prioritised artificial microRNAs against Sri Lankan cassava mosaic virus: a computational framework and its limits"
  authors:
    - family-names: "Nguyen"
      given-names: "Bang Phi"
  journal: "Functional & Integrative Genomics"
  year: 2026
  # doi: "10.1007/sXXXXX-XXX-XXXXX-X"   # điền sau khi bài được chấp nhận
CFF

# README — viết bằng tiếng Anh vì kho đi kèm bài báo tiếng Anh
cat > "$OUT/README.md" <<READMEEOF
# amirna-slcmv-durability

Code, derived data and figures for the article

> **Entropy- and population-scale design of durability-prioritised artificial
> microRNAs against Sri Lankan cassava mosaic virus: a computational framework
> and its limits**
> Bang Phi Nguyen. Submitted to *Functional & Integrative Genomics*, 2026.

[![License: MIT](https://img.shields.io/badge/code-MIT-blue.svg)](LICENSE)
[![Data: CC BY 4.0](https://img.shields.io/badge/data-CC%20BY%204.0-lightgrey.svg)](LICENSE-DATA.md)

---

## What this is

Existing artificial microRNA (amiRNA) design tools — WMD3, P-SAMS — optimise
the thermodynamic and positional properties of the small RNA itself and screen
for host off-targets against a single reference sequence. They were built for
silencing *plant* genes, where there is no variable pathogen population to
consider. Applied to a rapidly evolving virus they therefore say nothing about
how long a construct will keep working.

This pipeline brings population-scale evidence into the ranking, and keeps two
things apart that are usually summed into one number:

| | |
|---|---|
| **Durability Score** | conservation (Shannon entropy), population coverage, positionally weighted Escape Risk Index, synonymous escape room (\$\\pi_S\$), cross-target breadth |
| **Efficacy Score** | design-rule compliance (Schwab 2006; Ossowski 2008) and secondary-structure accessibility |

They are kept apart because in the hold-out experiments reported in the paper
the rule score predicted future population coverage in the **wrong direction**
(\$\\rho\$ between \$-0.245\$ and \$-0.289\$). Summing the two would have hidden that.

## What the paper concludes — including what did not work

Read the article for the full account; the short version, so that nobody has to
discover it by reading the code:

- Targeting invariant sites **transfers** well. Candidates designed on pre-2018
  records keep a median coverage of 1.0000 on records collected later.
- The composite Durability Score does **not** yet rank candidates reliably. In
  the temporal split it was constant, so no rank correlation is defined; in the
  geographic split it was positive for DNA-A and significantly negative for
  DNA-B.
- The retrospective joint-escape test has **no power**: zero joint escape is a
  consequence of the selection filter, not an independent result.
- The forward escape model uses point substitutions only. Begomoviruses
  recombine, and SLCMV DNA-A is close to monopartite and can trans-replicate a
  heterologous DNA-B — a route the framework does not model.

The score should be used as a filter and a tie-breaker, not as a calibrated
predictor, until resistance phenotypes exist to fit it against.

## Repository layout

\`\`\`
amirna.sh              single-file installer; embeds the whole tree
run_all.sh             stage orchestrator (--from / --to / --skip)
config/
  config.example.sh    copy to config.sh and fill in your NCBI e-mail
  targets.tsv          target definitions and design/validation roles
scripts/               14 pipeline stages (Bash) + scripts/py (Python)
R/                     00_load_data.R, 01_figures.R, 01_figures_en.R, 02_stats.R
envs/                  conda environment specification
tests/                 206-assertion offline test suite on synthetic data
data/final/            all derived tables (TSV) + tool_versions.txt
results/figures/       figures with Vietnamese labels (pipeline native)
results/figures_en/    figures with English labels (used in the article)
results/amirna_data.rds  serialised R object; enough to redraw every figure
\`\`\`

Raw GenBank records are **not** included: they are 18 MB of public data that
step 01 re-downloads. The accession list is
\`data/final/supplementary_S1_accessions.tsv\`.

## Reproducing

Requires Linux or WSL, conda/mamba, and roughly 2 hours on 4 threads.

\`\`\`bash
bash amirna.sh install            # unpack into ~/amirna_work
cd ~/amirna_work
cp config/config.example.sh config/config.sh
\$EDITOR config/config.sh          # NCBI_EMAIL is required by NCBI
bash amirna.sh setup              # create the conda environment
bash amirna.sh doctor             # check tools, RAM, disk, network
bash amirna.sh test               # 206 offline assertions, no network needed
bash amirna.sh run --bg           # full pipeline, logs to logs/run_*.log
bash amirna.sh rload              # load results into R, write results/*.rds
\`\`\`

To redraw the figures only, without re-running the analysis:

\`\`\`bash
Rscript --vanilla R/01_figures_en.R .     # English labels  -> results/figures_en/
Rscript --vanilla R/01_figures.R .        # Vietnamese      -> results/figures/
\`\`\`

Every stage is idempotent: a stage that already has output is skipped, so
\`run_all.sh --from N\` resumes cleanly after a failure.

## Software versions

The exact versions used for the published analysis are recorded automatically
in \`data/final/tool_versions.txt\` (MAFFT 7.526, SeqKit 2.14.0, ViennaRNA
2.6.4, bowtie 1.3.1, NCBI datasets 18.41.0, Python 3.11.18, R 4.6.2).

## Licence

Code: MIT (\`LICENSE\`). Data tables and figures: CC BY 4.0
(\`LICENSE-DATA.md\`). Genome sequences are not redistributed.

## Citation

See \`CITATION.cff\`. Please cite both the software archive and the article.
READMEEOF

# ---------------------------------------------------------------------
# 7. Che email cá nhân trên toàn bộ cây đã dựng
# ---------------------------------------------------------------------
echo "[7/8] Che email cá nhân trong các tệp đã sao chép…"
if [ -n "$EMAIL" ]; then
  esc="$(printf '%s' "$EMAIL" | sed -e 's/[\/&.]/\\&/g')"
  n=0
  while IFS= read -r f; do
    sed -i "s/$esc/your.email@example.org/g" "$f" && n=$((n+1))
  done < <(grep -rIl "$EMAIL" "$OUT" 2>/dev/null)
  echo "      đã thay trong $n tệp (giữ nguyên ở cây làm việc gốc)"
else
  echo "      không xác định được email để che — kiểm tra bằng ghscan"
fi

# ---------------------------------------------------------------------
# 8. Bản kê và tổng kiểm
# ---------------------------------------------------------------------
echo "[8/8] Sinh MANIFEST.md và SHA256SUMS.txt…"

# MANIFEST trước, SHA256SUMS sau — và SHA256SUMS phải TỰ LOẠI MÌNH ra,
# nếu không `sha256sum -c` luôn báo FAILED ở chính dòng của nó.
# du dùng --apparent-size vì ổ NTFS gắn qua drvfs báo 0 cho tệp nhỏ.
{
  echo "# Manifest"
  echo
  echo "Generated $(date -u '+%Y-%m-%d %H:%M UTC') by \`ghprep.sh\`."
  echo
  echo "| Path | Files | Size |"
  echo "|---|---|---|"
  ( cd "$OUT" && for d in scripts R envs tests config data/final \
      results/figures results/figures_en manuscript; do
      [ -d "$d" ] || continue
      printf '| `%s/` | %s | %s |\n' "$d" \
        "$(find "$d" -type f | wc -l)" \
        "$(du -sh --apparent-size "$d" 2>/dev/null | cut -f1)"
    done )
  echo
  echo "Integrity: \`sha256sum -c SHA256SUMS.txt\`"
} > "$OUT/MANIFEST.md"

( cd "$OUT" && find . -type f \
    -not -path './.git/*' -not -name 'SHA256SUMS.txt' -print0 \
    | sort -z | xargs -0 sha256sum > SHA256SUMS.txt )
echo "      $(wc -l < "$OUT/SHA256SUMS.txt") tệp được băm"

echo
echo "=== Quét bí mật"
if bash "$W/claude_cmds/ghscan.sh" "$OUT"; then
  echo
  echo "=== XONG. Kho đã dựng tại: $OUT"
  du -sh "$OUT" | awk '{print "    tổng dung lượng: "$1}'
  echo
  echo "Bước tiếp theo:"
  echo "    1. Đọc qua $OUT/README.md và điền ORCID vào CITATION.cff"
  echo "    2. bash c ghpush            # tạo commit cục bộ, CHƯA đẩy lên"
  echo "    3. bash c ghpush --push ... # xem hướng dẫn trong ghpush.sh"
else
  echo
  echo "=== DỪNG: quét bí mật phát hiện vấn đề. Sửa rồi chạy lại ghprep."
  exit 1
fi
