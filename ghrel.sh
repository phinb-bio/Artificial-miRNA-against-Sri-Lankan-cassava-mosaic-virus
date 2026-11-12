#!/usr/bin/env bash
# =====================================================================
#  ghrel.sh — Gắn thẻ phiên bản, tạo GitHub Release, lấy DOI Zenodo
#
#  Dùng:
#    bash c ghrel                      # chỉ in hướng dẫn + kiểm tra điều kiện
#    bash c ghrel --tag v1.0.0 --go    # thật sự tạo thẻ và release
#
#  THỨ TỰ RẤT QUAN TRỌNG. Zenodo chỉ lưu trữ những release được tạo SAU
#  khi anh bật kho đó trong Zenodo. Tạo release trước rồi mới bật Zenodo
#  thì release đó KHÔNG có DOI, và anh phải tạo thêm một release nữa.
#  Vì vậy script này mặc định chỉ in hướng dẫn; phải có --go mới chạy thật.
# =====================================================================
set -euo pipefail

W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$W/github_repo"
TAG="v1.0.0"; GO=0
TITLE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --tag) TAG="${2:?thiếu thẻ}"; shift 2 ;;
    --title) TITLE="${2:?thiếu tiêu đề}"; shift 2 ;;
    --go) GO=1; shift ;;
    -h|--help) sed -n '2,16p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "Tham số lạ: $1"; exit 2 ;;
  esac
done
[ -n "$TITLE" ] || TITLE="$TAG — analysis accompanying the SLCMV amiRNA durability manuscript"

[ -d "$REPO/.git" ] || { echo "LỖI: chưa có kho Git. Chạy 'bash c ghpush' trước."; exit 2; }
cd "$REPO"

cat <<'GUIDE'
=====================================================================
 QUY TRÌNH LẤY DOI TRÍCH DẪN ĐƯỢC CHO KHO MÃ NGUỒN
=====================================================================

Tạp chí yêu cầu mục "Code availability" trỏ tới một bản lưu trữ ổn
định, không phải một đường dẫn GitHub có thể đổi hoặc biến mất. Zenodo
giải quyết việc này: nó sao lưu một release của kho và cấp DOI.

Làm ĐÚNG THỨ TỰ sau:

  1. Vào https://zenodo.org, đăng nhập BẰNG TÀI KHOẢN GITHUB.
  2. Vào mục GitHub trong cài đặt tài khoản Zenodo.
  3. Bật công tắc cho kho amirna-slcmv-durability.
     (Nếu không thấy kho: bấm Sync now. Kho phải là public.)
  4. QUAY LẠI ĐÂY và chạy:  bash c ghrel --tag v1.0.0 --go
  5. Đợi 1–2 phút, tải lại trang Zenodo. Bản lưu trữ sẽ xuất hiện.
  6. Trên trang Zenodo của bản lưu trữ, anh sẽ thấy HAI DOI:
       - DOI của phiên bản  (10.5281/zenodo.NNNNNNN)
       - DOI khái niệm      "Cite all versions" — SỐ NHỎ HƠN
     => Dùng DOI KHÁI NIỆM trong bài báo. Nó luôn trỏ tới phiên bản
        mới nhất, nên nếu sau này anh sửa code thì trích dẫn vẫn đúng.
  7. Điền DOI đó vào:
       - manuscript: mục Declarations → Code availability
       - CITATION.cff: trường `doi:` và `repository-code:`
     rồi commit lần nữa (không cần release mới cho việc sửa metadata).

Lưu ý về siêu dữ liệu: Zenodo đọc CITATION.cff để điền tên tác giả,
ORCID và giấy phép. Hãy điền ORCID vào CITATION.cff TRƯỚC bước 4, nếu
không bản ghi Zenodo sẽ thiếu và phải sửa tay.

=====================================================================
GUIDE

echo
echo "=== Kiểm tra điều kiện"

ok=1
if git remote get-url origin >/dev/null 2>&1; then
  echo "  [ok]  origin = $(git remote get-url origin)"
else
  echo "  [!]   chưa có remote origin — chạy 'bash c ghpush --push …' trước"; ok=0
fi

if [ -z "$(git status --porcelain)" ]; then
  echo "  [ok]  cây làm việc sạch"
else
  echo "  [!]   còn thay đổi chưa commit:"; git status --short | sed 's/^/          /'; ok=0
fi

if grep -q '^\s*#\s*orcid:' CITATION.cff 2>/dev/null; then
  echo "  [!]   CITATION.cff: ORCID vẫn đang bị chú thích — điền trước khi phát hành"
else
  echo "  [ok]  CITATION.cff có ORCID"
fi

if grep -q '<USERNAME>' CITATION.cff 2>/dev/null; then
  echo "  [!]   CITATION.cff: repository-code vẫn là <USERNAME> — sửa lại"
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "  [!]   thẻ $TAG đã tồn tại. Dùng --tag với số phiên bản khác."; ok=0
else
  echo "  [ok]  thẻ $TAG chưa tồn tại"
fi

if [ "$GO" = "0" ]; then
  echo
  echo "=== Chế độ xem trước. Chưa tạo gì."
  echo "    Khi đã làm xong bước 1–3 ở trên, chạy:"
  echo "        bash c ghrel --tag $TAG --go"
  exit 0
fi

[ "$ok" = "1" ] || { echo; echo "DỪNG: còn điều kiện chưa đạt ở trên."; exit 1; }

# --- Ghi chú phát hành -------------------------------------------------
NOTES="$(mktemp)"
cat > "$NOTES" <<'RELNOTES'
Analysis release accompanying the manuscript

**Entropy- and population-scale design of durability-prioritised artificial
microRNAs against Sri Lankan cassava mosaic virus: a computational framework
and its limits**

This archive contains the complete pipeline (14 stages, Bash/Python/R), the
206-assertion offline test suite, every derived data table, and the figures as
published.

Contents
- `scripts/`, `R/`, `tests/`, `envs/`, `amirna.sh` — the pipeline
- `data/final/` — all derived tables, including the accession list for the
  1046 GenBank records analysed and the exact tool versions used
- `results/figures/`, `results/figures_en/` — figures, 300 dpi
- `results/amirna_data.rds` — serialised R object; sufficient to redraw every
  figure without re-running the analysis

Not included: the raw GenBank records (public data, re-downloaded by stage 01)
and `config/config.sh` (holds a personal NCBI contact e-mail).

Reproducibility: every stage is idempotent and the test suite runs offline on
synthetic data with planted signals, including a planted reciprocal
recombination event used to confirm that the four-gamete implementation
detects recombination when it is present and only then.
RELNOTES

echo
echo "=== git tag -a $TAG"
git tag -a "$TAG" -m "$TITLE"
echo "=== git push origin $TAG"
git push origin "$TAG"

if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  echo "=== gh release create $TAG"
  gh release create "$TAG" --title "$TITLE" --notes-file "$NOTES"
  echo
  echo "=== XONG. Release đã tạo."
  gh release view "$TAG" --json url -q .url 2>/dev/null | sed 's/^/    /' || true
else
  echo
  echo "=== Thẻ đã được đẩy lên, nhưng chưa có gh CLI nên CHƯA tạo Release."
  echo "    Zenodo chỉ phản ứng với RELEASE, không phải thẻ. Vào:"
  echo "        https://github.com/<user>/<repo>/releases/new?tag=$TAG"
  echo "    và dán nội dung sau vào ô mô tả:"
  echo
  sed 's/^/    /' "$NOTES"
fi
rm -f "$NOTES"

echo
echo "Nhắc lại: đợi 1–2 phút rồi kiểm tra Zenodo, lấy DOI KHÁI NIỆM"
echo "(\"Cite all versions\"), không phải DOI của riêng phiên bản này."
