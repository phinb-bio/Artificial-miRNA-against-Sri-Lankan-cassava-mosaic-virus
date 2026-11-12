#!/usr/bin/env bash
# =====================================================================
#  ghscan.sh — Quét bí mật trước khi công bố mã nguồn
#
#  Dùng:  bash c ghscan [THU_MUC]
#         (mặc định quét github_repo/)
#
#  Mã thoát: 0 = sạch, 1 = PHÁT HIỆN, 2 = lỗi tham số.
#  Script CHỈ ĐỌC, không sửa và không xoá bất cứ thứ gì.
#
#  Lý do tồn tại: lịch sử Git là vĩnh viễn. Một khoá API lọt vào commit
#  đầu tiên vẫn còn đó sau khi ta "xoá" nó ở commit sau. Rẻ hơn rất
#  nhiều nếu chặn ngay trước lần commit đầu.
# =====================================================================
set -uo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  TARGET="$W/github_repo"
fi
[ -d "$TARGET" ] || { echo "LỖI: không thấy thư mục '$TARGET'"; exit 2; }

echo "=== Quét bí mật trong: $TARGET"
echo

hits=0
report() {   # report <nhãn> <mẫu regex> <mức: CHAN|CANHBAO>
  local label="$1" pat="$2" level="$3" n f
  # Bỏ qua .git và các tệp nhị phân
  mapfile -t f < <(grep -rIlE "$pat" "$TARGET" --exclude-dir=.git 2>/dev/null)
  n=${#f[@]}
  if [ "$n" -gt 0 ]; then
    if [ "$level" = "CHAN" ]; then
      echo "  [CHẶN]    $label — $n tệp:"
      hits=$((hits+1))
    else
      echo "  [CẢNH BÁO] $label — $n tệp:"
    fi
    printf '              %s\n' "${f[@]#$TARGET/}"
  else
    echo "  [sạch]    $label"
  fi
}

# --- Những thứ KHÔNG BAO GIỜ được đẩy lên -----------------------------
# Khoá API NCBI: 36 ký tự hex thường. Bắt cả dạng gán biến lẫn dạng
# tham số dòng lệnh (--api-key=..., api_key=...).
report "Khoá API NCBI (gán biến)"      'NCBI_API_KEY[[:space:]]*=[[:space:]]*"?[A-Za-z0-9]{20,}' CHAN
report "Khoá API (dạng tham số URL)"   '[?&]api_key=[A-Za-z0-9]{20,}'                            CHAN
report "Khoá API (cờ dòng lệnh)"       '--api-key[= ][A-Za-z0-9]{20,}'                           CHAN
report "Khoá riêng SSH/PGP"            'BEGIN [A-Z ]*PRIVATE KEY'                                CHAN
report "Token GitHub"                  '\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{30,}'                CHAN
report "Khoá AWS"                      '\bAKIA[0-9A-Z]{16}\b'                                    CHAN
report "Gán password/secret/token"     '(password|passwd|secret|token)[[:space:]]*=[[:space:]]*"[^"]{8,}"' CHAN

# --- Những thứ nên xem lại, không nhất thiết chặn ---------------------
report "Địa chỉ email"                 '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'          CANHBAO
report "Đường dẫn tuyệt đối máy cá nhân" '(/home/[a-z0-9_-]+/|/mnt/[a-z]/|[A-Z]:\\\\)'           CANHBAO

echo
# --- Tệp to: GitHub chặn >100 MB, cảnh báo từ 50 MB -------------------
echo "=== Tệp lớn hơn 20 MB (GitHub chặn cứng ở 100 MB)"
big=$(find "$TARGET" -type f -size +20M -not -path '*/.git/*' 2>/dev/null)
if [ -n "$big" ]; then echo "$big" | sed "s|$TARGET/|  |"; hits=$((hits+1));
else echo "  (không có)"; fi

echo
echo "=== Tổng dung lượng"; du -sh "$TARGET" 2>/dev/null | awk '{print "  "$1}'

echo
if [ "$hits" -gt 0 ]; then
  echo "KẾT LUẬN: CÓ $hits nhóm vấn đề mức CHẶN. KHÔNG được đẩy lên."
  exit 1
fi
echo "KẾT LUẬN: không phát hiện bí mật ở mức chặn."
echo "Các mục [CẢNH BÁO] ở trên vẫn nên xem qua bằng mắt — email và đường"
echo "dẫn cá nhân không nguy hiểm, nhưng là thứ anh nên chủ động quyết định."
exit 0
