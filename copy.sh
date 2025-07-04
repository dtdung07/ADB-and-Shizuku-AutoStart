#!/data/data/com.termux/files/usr/bin/bash

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Không màu

# Cấu hình
BASEDIR=$( dirname "${0}" )
BIN=/data/data/com.termux/files/usr/bin
HOME=/data/data/com.termux/files/home
DEX="${BASEDIR}/rish_shizuku.dex"
ADBW_PORT="${BASEDIR}/adbw_port"

# Hàm ghi log
log() {
    echo -e "${BLUE}[THÔNG TIN]${NC} $1"
}

error() {
    echo -e "${RED}[LỖI]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[THÀNH CÔNG]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[CẢNH BÁO]${NC} $1"
}

# Kiểm tra trước khi cài đặt
log "Đang kiểm tra các file cần thiết..."

# Kiểm tra file bắt buộc tồn tại
if [ ! -f "${DEX}" ]; then
    error "Không tìm thấy file rish_shizuku.dex tại: ${DEX}"
    error "Vui lòng tải file này từ: https://github.com/Mirai0009/Get-Url-via-Shizuku-Termux"
    exit 1
fi

if [ ! -f "${ADBW_PORT}" ]; then
    error "Không tìm thấy file adbw_port tại: ${ADBW_PORT}"
    exit 1
fi

# Đảm bảo adbw_port binaries có quyền thực thi
log "Đang cấp quyền thực thi cho adbw_port tools..."
chmod +x "${ADBW_PORT}" "${BASEDIR}/adbw_port_arm.bin" "${BASEDIR}/adbw_port_arm64.bin" 2>/dev/null || {
    warn "Không thể cấp quyền cho một số binary files (có thể không tồn tại)"
}

# Kiểm tra quyền ghi
if [ ! -w "${BIN}" ]; then
    error "Không có quyền ghi vào thư mục: ${BIN}"
    exit 1
fi

if [ ! -w "${HOME}" ]; then
    error "Không có quyền ghi vào thư mục: ${HOME}"
    exit 1
fi

# Bật external apps trong Termux (cần thiết cho adbw_port)
log "Đang cấu hình Termux để cho phép external apps..."
value="true"
key="allow-external-apps"
file="/data/data/com.termux/files/home/.termux/termux.properties"
mkdir -p "$(dirname "$file")"
chmod 700 "$(dirname "$file")"
TERMUX_RESTART_NEEDED=false
if ! grep -E '^'"$key"'=.*' "$file" &>/dev/null; then
    [[ -s "$file" && ! -z "$(tail -c 1 "$file")" ]] && newline=$'\n' || newline=""
    echo "$newline$key=$value" >> "$file"
    success "Đã bật allow-external-apps trong Termux"
    TERMUX_RESTART_NEEDED=true
else
    if ! grep -E '^'"$key"'=true' "$file" &>/dev/null; then
        sed -i'' -E 's/^'"$key"'=.*/'"$key=$value"'/' "$file"
        success "Đã cập nhật allow-external-apps=true"
        TERMUX_RESTART_NEEDED=true
    else
        log "allow-external-apps đã được bật"
    fi
fi

# Kiểm tra xem adb có sẵn không
if ! command -v adb >/dev/null 2>&1; then
    warn "ADB chưa được cài đặt. Đang cài đặt..."
    pkg install android-tools
fi

log "Tất cả kiểm tra đã thành công!"

# Tạo script Shizuku nâng cao
log "Đang tạo script Shizuku..."
tee "${BIN}/shizuku" > /dev/null << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Lấy thư mục script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADBW_PORT_SCRIPT=""

# Tìm adbw_port ở các vị trí thông thường
for path in "${SCRIPT_DIR}" "${HOME}" "${HOME}/shizuku-autostart" "/data/data/com.termux/files/home" "$(pwd)"; do
    if [ -f "${path}/adbw_port" ]; then
        ADBW_PORT_SCRIPT="${path}/adbw_port"
        break
    fi
done

if [ -z "$ADBW_PORT_SCRIPT" ] || [ ! -f "$ADBW_PORT_SCRIPT" ]; then
    echo -e "${RED}LỖI: Không tìm thấy adbw_port script!${NC}"
    exit 1
fi

echo -e "${BLUE}[THÔNG TIN]${NC} Sử dụng adbw_port từ: $ADBW_PORT_SCRIPT"

# Chuyển đến thư mục chứa adbw_port
cd "$(dirname "$ADBW_PORT_SCRIPT")" || exit 1

# Lấy cổng ADB wireless
echo -e "${BLUE}[THÔNG TIN]${NC} Đang tìm kiếm cổng ADB wireless..."
read ip port < <(./adbw_port _adb._tcp.local. 2>/dev/null \
  | sed -n -e 's/.*ipv4: \([0-9.]*\), port: \([0-9]*\).*/\1 \2/p')

device="${ip}:${port}"

if [[ -z "$ip" || -z "$port" ]]; then
    echo -e "${RED}LỖI: Không tìm thấy IP hoặc port!${NC}"
    echo -e "${YELLOW}Đảm bảo rằng:${NC}"
    echo "  1. Wireless debugging đã được bật"
    echo "  2. Thiết bị đã được ghép nối"
    echo "  3. Đang kết nối cùng mạng WiFi"
    
    echo -e "${BLUE}Thông tin debug:${NC}"
    ./adbw_port _adb._tcp.local.
    exit 1
fi

echo -e "${BLUE}[THÔNG TIN]${NC} Tìm thấy thiết bị: $device"

# Kết nối đến ADB
echo -e "${BLUE}[THÔNG TIN]${NC} Đang kết nối ADB..."
if ! adb -s "$device" connect "$device" >/dev/null 2>&1; then
    echo -e "${RED}LỖI: Không thể kết nối ADB đến $device${NC}"
    exit 1
fi

# Xác minh kết nối
if ! adb -s "$device" shell echo connected >/dev/null 2>&1; then
    echo -e "${RED}LỖI: Kết nối ADB thất bại${NC}"
    exit 1
fi

echo -e "${GREEN}[THÀNH CÔNG]${NC} Kết nối ADB thành công!"

# Kiểm tra ứng dụng Shizuku đã cài đặt chưa
echo -e "${BLUE}[THÔNG TIN]${NC} Đang kiểm tra ứng dụng Shizuku..."
if ! adb -s "$device" shell pm path --user 0 moe.shizuku.privileged.api >/dev/null 2>&1; then
    echo -e "${RED}LỖI: Ứng dụng Shizuku chưa được cài đặt!${NC}"
    echo -e "${YELLOW}Vui lòng cài đặt Shizuku từ Play Store hoặc GitHub.${NC}"
    exit 1
fi

# Lấy đường dẫn Shizuku
sh_path=$(adb -s "$device" shell pm path --user 0 moe.shizuku.privileged.api 2>/dev/null \
  | sed 's/^package://')

if [ -z "$sh_path" ]; then
    echo -e "${RED}LỖI: Không thể lấy đường dẫn Shizuku${NC}"
    exit 1
fi

lib_path=$(adb -s "$device" shell "echo \$(dirname \"$sh_path\")/lib/*/libshizuku.so" 2>/dev/null)

if [ -z "$lib_path" ]; then
    echo -e "${RED}LỖI: Không thể tìm thấy libshizuku.so${NC}"
    exit 1
fi

echo -e "${BLUE}[THÔNG TIN]${NC} Đang khởi động Shizuku từ: $lib_path"

# Khởi động Shizuku
if adb -s "$device" shell "$lib_path" >/dev/null 2>&1; then
    echo -e "${GREEN}[THÀNH CÔNG]${NC} Shizuku đã được khởi động thành công!"
    
    # Đợi một chút để Shizuku khởi tạo
    sleep 2
    
    # Xác minh Shizuku đang chạy
    if adb -s "$device" shell pgrep -f shizuku >/dev/null 2>&1; then
        echo -e "${GREEN}[THÀNH CÔNG]${NC} Shizuku đang chạy!"
    else
        echo -e "${YELLOW}[CẢNH BÁO]${NC} Không thể xác minh trạng thái Shizuku"
    fi
    
    # Tắt wireless debugging
    echo -e "${BLUE}[THÔNG TIN]${NC} Đang tắt wireless debugging..."
    adb -s "$device" shell settings put global adb_wifi_enabled 0 2>/dev/null
    echo -e "${GREEN}[THÀNH CÔNG]${NC} Đã tắt wireless debugging"
    
    exit 0
else
    echo -e "${RED}LỖI: Khởi động Shizuku thất bại${NC}"
    exit 1
fi
EOF

# Sử dụng vị trí dex gốc (không cần copy)
dex="${DEX}"

# Tạo script Rish nâng cao
log "Đang tạo script Rish..."
tee "${BIN}/rish" > /dev/null << EOF
#!/data/data/com.termux/files/usr/bin/bash

# Định nghĩa các vị trí có thể có của dex
DEX_LOCATIONS=(
    "${dex}"
    "\${HOME}/rish_shizuku.dex"
    "\${HOME}/shizuku-autostart/rish_shizuku.dex"
    "/data/data/com.termux/files/home/shizuku-autostart/rish_shizuku.dex"
)

# Tìm file dex
FOUND_DEX=""
for dex_path in "\${DEX_LOCATIONS[@]}"; do
    if [ -f "\$dex_path" ] && [ -r "\$dex_path" ]; then
        FOUND_DEX="\$dex_path"
        break
    fi
done

if [ -z "\$FOUND_DEX" ]; then
    echo -e "\033[0;31mLỖI: Không tìm thấy rish_shizuku.dex ở bất kỳ vị trí nào!\033[0m" >&2
    echo -e "\033[1;33mCác vị trí đã kiểm tra:\033[0m" >&2
    for dex_path in "\${DEX_LOCATIONS[@]}"; do
        echo -e "  - \$dex_path" >&2
    done
    echo -e "\033[1;33mVui lòng chạy lại script cài đặt: copy.sh\033[0m" >&2
    exit 1
fi

# Đặt application ID mặc định nếu chưa có
[ -z "\$RISH_APPLICATION_ID" ] && export RISH_APPLICATION_ID="com.termux"

# Chạy rish với xử lý lỗi phù hợp
exec /system/bin/app_process -Djava.class.path="\$FOUND_DEX" /system/bin --nice-name=rish rikka.shizuku.shell.ShizukuShellLoader "\${@}"
EOF

# Cấp quyền thực thi
log "Đang cấp quyền thực thi..."
if ! chmod +x "${BIN}/shizuku" "${BIN}/rish"; then
    error "Không thể cấp quyền thực thi cho các script"
    exit 1
fi

# Đặt quyền phù hợp cho file dex gốc (cần thiết cho app_process)
log "Đang thiết lập quyền cho file DEX gốc..."
if ! chmod -w "${DEX}"; then
    warn "Không thể thiết lập quyền cho file DEX (có thể không ảnh hưởng)"
fi

# Kiểm tra cuối cùng
log "Đang kiểm tra cài đặt..."
if [ -x "${BIN}/shizuku" ] && [ -x "${BIN}/rish" ] && [ -r "${DEX}" ]; then
    success "🎉 Cài đặt hoàn tất thành công!"
    echo
    log "Các lệnh đã được tạo:"
    echo "  📱 shizuku: Script khởi động Shizuku"
    echo "  🛠️ rish: Shell tool qua Shizuku (sử dụng DEX từ: ${DEX})"
    echo
    if [ "$TERMUX_RESTART_NEEDED" = true ]; then
        warn "⚠️  VUI LÒNG KHỞI ĐỘNG LẠI TERMUX APP để allow-external-apps có hiệu lực!"
        echo "   1. Tắt hoàn toàn ứng dụng Termux"
        echo "   2. Mở lại Termux"
        echo "   3. Sau đó chạy 'shizuku' để thử nghiệm"
        echo
    fi
    
    log "🚀 Bây giờ bạn có thể:"
    echo "  1. Import macro vào MacroDroid"
    echo "  2. Chạy 'shizuku' để thử nghiệm thủ công"
    echo "  3. Sử dụng 'rish' để chạy lệnh với quyền cao"
else
    error "❌ Cài đặt không hoàn chỉnh. Vui lòng kiểm tra lại!"
    exit 1
fi