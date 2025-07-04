#!/data/data/com.termux/files/usr/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASEDIR=$( dirname "${0}" )
BIN=/data/data/com.termux/files/usr/bin
HOME=/data/data/com.termux/files/home
DEX="${BASEDIR}/rish_shizuku.dex"
ADBW_PORT="${BASEDIR}/adbw_port"

# Logging function
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Pre-installation checks
log "Kiểm tra các file cần thiết..."

# Check if required files exist
if [ ! -f "${DEX}" ]; then
    error "Không tìm thấy file rish_shizuku.dex tại: ${DEX}"
    error "Vui lòng tải file này từ: https://github.com/Mirai0009/Get-Url-via-Shizuku-Termux"
    exit 1
fi

if [ ! -f "${ADBW_PORT}" ]; then
    error "Không tìm thấy file adbw_port tại: ${ADBW_PORT}"
    exit 1
fi

# Ensure adbw_port binaries have execute permissions
log "Đang cấp quyền thực thi cho adbw_port tools..."
chmod +x "${ADBW_PORT}" "${BASEDIR}/adbw_port_arm.bin" "${BASEDIR}/adbw_port_arm64.bin" 2>/dev/null || {
    warn "Không thể cấp quyền cho một số binary files (có thể không tồn tại)"
}

# Check write permissions
if [ ! -w "${BIN}" ]; then
    error "Không có quyền ghi vào thư mục: ${BIN}"
    exit 1
fi

if [ ! -w "${HOME}" ]; then
    error "Không có quyền ghi vào thư mục: ${HOME}"
    exit 1
fi

# Enable external apps in Termux (required for adbw_port)
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
    success "Đã enable allow-external-apps trong Termux"
    TERMUX_RESTART_NEEDED=true
else
    if ! grep -E '^'"$key"'=true' "$file" &>/dev/null; then
        sed -i'' -E 's/^'"$key"'=.*/'"$key=$value"'/' "$file"
        success "Đã update allow-external-apps=true"
        TERMUX_RESTART_NEEDED=true
    else
        log "allow-external-apps đã được enable"
    fi
fi

# Check if adb is available
if ! command -v adb >/dev/null 2>&1; then
    warn "ADB chưa được cài đặt. Đang cài đặt..."
    pkg install android-tools
fi

log "Tất cả kiểm tra đã thành công!"

# Create enhanced Shizuku script
log "Tạo script Shizuku..."
tee "${BIN}/shizuku" > /dev/null << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADBW_PORT_SCRIPT=""

# Find adbw_port in common locations
for path in "${SCRIPT_DIR}" "${HOME}" "${HOME}/shizuku-autostart" "/data/data/com.termux/files/home" "$(pwd)"; do
    if [ -f "${path}/adbw_port" ]; then
        ADBW_PORT_SCRIPT="${path}/adbw_port"
        break
    fi
done

if [ -z "$ADBW_PORT_SCRIPT" ] || [ ! -f "$ADBW_PORT_SCRIPT" ]; then
    echo -e "${RED}ERROR: Không tìm thấy adbw_port script!${NC}"
    exit 1
fi

echo -e "${BLUE}[INFO]${NC} Sử dụng adbw_port từ: $ADBW_PORT_SCRIPT"

# Change to the directory containing adbw_port
cd "$(dirname "$ADBW_PORT_SCRIPT")" || exit 1

# Get ADB wireless port
echo -e "${BLUE}[INFO]${NC} Đang tìm kiếm cổng ADB wireless..."
read ip port < <(./adbw_port _adb._tcp.local. 2>/dev/null \
  | sed -n -e 's/.*ipv4: \([0-9.]*\), port: \([0-9]*\).*/\1 \2/p')

device="${ip}:${port}"

if [[ -z "$ip" || -z "$port" ]]; then
    echo -e "${RED}ERROR: Không tìm thấy IP hoặc port!${NC}"
    echo -e "${YELLOW}Đảm bảo rằng:${NC}"
    echo "  1. Wireless debugging đã được bật"
    echo "  2. Thiết bị đã được pair"
    echo "  3. Đang kết nối cùng mạng WiFi"
    
    echo -e "${BLUE}Debug output:${NC}"
    ./adbw_port _adb._tcp.local.
    exit 1
fi

echo -e "${BLUE}[INFO]${NC} Tìm thấy thiết bị: $device"

# Connect to ADB
echo -e "${BLUE}[INFO]${NC} Đang kết nối ADB..."
if ! adb -s "$device" connect "$device" >/dev/null 2>&1; then
    echo -e "${RED}ERROR: Không thể kết nối ADB đến $device${NC}"
    exit 1
fi

# Verify connection
if ! adb -s "$device" shell echo connected >/dev/null 2>&1; then
    echo -e "${RED}ERROR: Kết nối ADB thất bại${NC}"
    exit 1
fi

echo -e "${GREEN}[SUCCESS]${NC} Kết nối ADB thành công!"

# Check if Shizuku app is installed
echo -e "${BLUE}[INFO]${NC} Kiểm tra ứng dụng Shizuku..."
if ! adb -s "$device" shell pm path --user 0 moe.shizuku.privileged.api >/dev/null 2>&1; then
    echo -e "${RED}ERROR: Ứng dụng Shizuku chưa được cài đặt!${NC}"
    echo -e "${YELLOW}Vui lòng cài đặt Shizuku từ Play Store hoặc GitHub.${NC}"
    exit 1
fi

# Get Shizuku path
sh_path=$(adb -s "$device" shell pm path --user 0 moe.shizuku.privileged.api 2>/dev/null \
  | sed 's/^package://')

if [ -z "$sh_path" ]; then
    echo -e "${RED}ERROR: Không thể lấy đường dẫn Shizuku${NC}"
    exit 1
fi

lib_path=$(adb -s "$device" shell "echo \$(dirname \"$sh_path\")/lib/*/libshizuku.so" 2>/dev/null)

if [ -z "$lib_path" ]; then
    echo -e "${RED}ERROR: Không thể tìm thấy libshizuku.so${NC}"
    exit 1
fi

echo -e "${BLUE}[INFO]${NC} Đang khởi động Shizuku từ: $lib_path"

# Start Shizuku
if adb -s "$device" shell "$lib_path" >/dev/null 2>&1; then
    echo -e "${GREEN}[SUCCESS]${NC} Shizuku đã được khởi động thành công!"
    
    # Wait a moment for Shizuku to initialize
    sleep 2
    
    # Verify Shizuku is running
    if adb -s "$device" shell pgrep -f shizuku >/dev/null 2>&1; then
        echo -e "${GREEN}[SUCCESS]${NC} Shizuku đang chạy!"
    else
        echo -e "${YELLOW}[WARNING]${NC} Không thể xác minh trạng thái Shizuku"
    fi
    
    # Disable wireless debugging
    echo -e "${BLUE}[INFO]${NC} Đang tắt wireless debugging..."
    adb -s "$device" shell settings put global adb_wifi_enabled 0 2>/dev/null
    echo -e "${GREEN}[SUCCESS]${NC} Đã tắt wireless debugging"
    
    exit 0
else
    echo -e "${RED}ERROR: Khởi động Shizuku thất bại${NC}"
    exit 1
fi
EOF

# Use the original dex location (no copy needed)
dex="${DEX}"

# Create enhanced Rish script  
log "Tạo script Rish..."
tee "${BIN}/rish" > /dev/null << EOF
#!/data/data/com.termux/files/usr/bin/bash

# Define possible dex locations
DEX_LOCATIONS=(
    "${dex}"
    "\${HOME}/rish_shizuku.dex"
    "\${HOME}/shizuku-autostart/rish_shizuku.dex"
    "/data/data/com.termux/files/home/shizuku-autostart/rish_shizuku.dex"
)

# Find the dex file
FOUND_DEX=""
for dex_path in "\${DEX_LOCATIONS[@]}"; do
    if [ -f "\$dex_path" ] && [ -r "\$dex_path" ]; then
        FOUND_DEX="\$dex_path"
        break
    fi
done

if [ -z "\$FOUND_DEX" ]; then
    echo -e "\033[0;31mERROR: Không tìm thấy rish_shizuku.dex ở bất kỳ vị trí nào!\033[0m" >&2
    echo -e "\033[1;33mCác vị trí đã kiểm tra:\033[0m" >&2
    for dex_path in "\${DEX_LOCATIONS[@]}"; do
        echo -e "  - \$dex_path" >&2
    done
    echo -e "\033[1;33mVui lòng chạy lại script cài đặt: copy.sh\033[0m" >&2
    exit 1
fi

# Set default application ID if not set
[ -z "\$RISH_APPLICATION_ID" ] && export RISH_APPLICATION_ID="com.termux"

# Run rish with proper error handling
exec /system/bin/app_process -Djava.class.path="\$FOUND_DEX" /system/bin --nice-name=rish rikka.shizuku.shell.ShizukuShellLoader "\${@}"
EOF

# Give execution permissions
log "Đang cấp quyền thực thi..."
if ! chmod +x "${BIN}/shizuku" "${BIN}/rish"; then
    error "Không thể cấp quyền thực thi cho các script"
    exit 1
fi

# Set proper permissions for original dex file (required for app_process)
log "Đang thiết lập quyền cho file DEX gốc..."
if ! chmod -w "${DEX}"; then
    warn "Không thể thiết lập quyền cho file DEX (có thể không ảnh hưởng)"
fi

# Final verification
log "Đang kiểm tra cài đặt..."
if [ -x "${BIN}/shizuku" ] && [ -x "${BIN}/rish" ] && [ -r "${DEX}" ]; then
    success "Cài đặt hoàn tất thành công!"
    echo
    log "Các lệnh đã được tạo:"
    echo "  - shizuku: Script khởi động Shizuku"
    echo "  - rish: Shell tool qua Shizuku (sử dụng DEX từ: ${DEX})"
    echo
    if [ "$TERMUX_RESTART_NEEDED" = true ]; then
        warn "⚠️  VUI LÒNG RESTART TERMUX APP để allow-external-apps có hiệu lực!"
        echo "   1. Tắt hoàn toàn ứng dụng Termux"
        echo "   2. Mở lại Termux"
        echo "   3. Sau đó chạy 'shizuku' để test"
        echo
    fi
    
    log "Bây giờ bạn có thể:"
    echo "  1. Import macro vào MacroDroid"
    echo "  2. Chạy 'shizuku' để test thủ công"
    echo "  3. Sử dụng 'rish' để chạy lệnh với quyền cao"
else
    error "Cài đặt không hoàn chỉnh. Vui lòng kiểm tra lại!"
    exit 1
fi