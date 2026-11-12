#!/usr/bin/env bash
# =====================================================================
#  ghpush.sh — Tạo kho Git và (tuỳ chọn) đẩy lên GitHub
#
#  Dùng:
#    bash c ghpush                          # chỉ commit cục bộ, KHÔNG đẩy
#    bash c ghpush --push --gh --public     # tạo kho mới qua gh CLI rồi đẩy
#    bash c ghpush --push --remote <URL>    # đẩy lên kho đã tạo sẵn
#
#  Tuỳ chọn thêm:
#    --name TÊN        tên kho trên GitHub (mặc định amirna-slcmv-durability)
#    --public|--private   mức hiển thị khi dùng --gh (mặc định --public)
#    --message "..."   nội dung commit
#
#  Mặc định KHÔNG đẩy lên mạng. Phải có cờ --push một cách tường minh.
#  Script không bao giờ dùng `push --force` và không bao giờ xoá gì.
# =====================================================================
set -euo pipefail

W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$W/github_repo"
DO_PUSH=0; USE_GH=0; REMOTE=""; VIS="public"
NAME="amirna-slcmv-durability"
MSG="Pipeline, derived tables and figures for the SLCMV amiRNA durability study"

while [ $# -gt 0 ]; do
  case "$1" in
    --push) DO_PUSH=1; shift ;;
    --gh) USE_GH=1; shift ;;
    --remote) REMOTE="${2:?thiếu URL}"; shift 2 ;;
    --name) NAME="${2:?thiếu tên}"; shift 2 ;;
    --public) VIS="public"; shift ;;
    --private) VIS="private"; shift ;;
    --message) MSG="${2:?thiếu nội dung}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "Tham số lạ: $1"; exit 2 ;;
  esac
done

[ -d "$REPO" ] || { echo "LỖI: chưa có $REPO. Chạy 'bash c ghprep' trước."; exit 2; }
command -v git >/dev/null || { echo "LỖI: chưa cài git. Trong WSL: sudo apt install git (anh tự gõ, script không chạy sudo)."; exit 3; }

# --- Danh tính Git -----------------------------------------------------
if ! git config --global user.name >/dev/null 2>&1 || ! git config --global user.email >/dev/null 2>&1; then
  echo "LỖI: git chưa có danh tính. Chạy hai lệnh sau rồi thử lại:"
  echo '    git config --global user.name  "Bang Phi Nguyen"'
  echo '    git config --global user.email "ban@email.cua.anh"'
  echo
  echo "Lưu ý: email này sẽ GẮN VĨNH VIỄN vào mọi commit công khai."
  echo "Muốn giấu, dùng địa chỉ noreply của GitHub:"
  echo "    <id>+<username>@users.noreply.github.com"
  exit 3
fi

# --- Quét bí mật lần nữa, ngay trước khi commit ------------------------
echo "=== Quét bí mật trước khi commit"
bash "$W/claude_cmds/ghscan.sh" "$REPO" || {
  echo "DỪNG: không commit khi còn cảnh báo mức chặn."; exit 1; }
echo

cd "$REPO"

# --- Khởi tạo kho ------------------------------------------------------
if [ ! -d .git ]; then
  echo "=== git init"
  if git init -b main >/dev/null 2>&1; then :; else
    git init >/dev/null
    git symbolic-ref HEAD refs/heads/main
  fi
else
  echo "=== Đã có .git — commit tiếp vào kho hiện tại"
fi

git add -A
if git diff --cached --quiet; then
  echo "=== Không có thay đổi nào để commit"
else
  git commit -q -m "$MSG"
  echo "=== Đã commit: $(git rev-parse --short HEAD)"
fi

echo
echo "=== Nội dung kho"
git -c core.quotepath=false ls-files | wc -l | awk '{print "    "$1" tệp được theo dõi"}'
du -sh .git 2>/dev/null | awk '{print "    .git: "$1}'
echo "    5 tệp lớn nhất:"
git ls-files -z | xargs -0 du -h 2>/dev/null | sort -rh | head -5 | sed 's/^/      /'

# --- Dừng ở đây nếu không có --push ------------------------------------
if [ "$DO_PUSH" = "0" ]; then
  cat <<'NEXT'

=== Đã tạo commit cục bộ. CHƯA đẩy lên mạng.

Kiểm tra lại bằng mắt trước khi công bố:
    cd github_repo && git log --stat | head -40
    git ls-files | less

Khi đã sẵn sàng, chọn MỘT trong hai cách:

  (A) Để gh CLI tự tạo kho — cần `gh auth login` một lần trước:
        bash c ghpush --push --gh --public

  (B) Tự tạo kho rỗng trên github.com (KHÔNG tích "Add a README"),
      rồi dán URL vào:
        bash c ghpush --push --remote https://github.com/<user>/<repo>.git

Lịch sử Git là vĩnh viễn: một bí mật lọt vào commit đầu vẫn còn đó sau
khi commit sau xoá nó đi. Đó là lý do bước quét chạy hai lần.
NEXT
  exit 0
fi

# --- Đẩy lên -----------------------------------------------------------
if [ "$USE_GH" = "1" ]; then
  command -v gh >/dev/null || { echo "LỖI: chưa cài gh CLI. Xem https://cli.github.com, hoặc dùng --remote."; exit 3; }
  gh auth status >/dev/null 2>&1 || { echo "LỖI: gh chưa đăng nhập. Chạy: gh auth login"; exit 3; }
  echo "=== gh repo create $NAME --$VIS"
  gh repo create "$NAME" --"$VIS" --source=. --remote=origin --push \
    --description "Durability-prioritised amiRNA design against Sri Lankan cassava mosaic virus: pipeline, derived tables and figures"
elif [ -n "$REMOTE" ]; then
  if git remote get-url origin >/dev/null 2>&1; then
    echo "=== origin đã tồn tại: $(git remote get-url origin)"
    [ "$(git remote get-url origin)" = "$REMOTE" ] || {
      echo "LỖI: origin hiện tại khác URL anh đưa. Tự kiểm tra rồi dùng"
      echo "     git remote set-url origin <URL>  nếu chắc chắn."; exit 4; }
  else
    git remote add origin "$REMOTE"
  fi
  echo "=== git push -u origin main"
  git push -u origin main
else
  echo "LỖI: --push cần kèm --gh hoặc --remote <URL>."; exit 2
fi

echo
echo "=== XONG. Kho đã lên GitHub."
git remote get-url origin | sed 's/^/    /' || true
echo
echo "Bước tiếp theo: bash c ghrel   (gắn thẻ phiên bản + tạo release + Zenodo DOI)"
