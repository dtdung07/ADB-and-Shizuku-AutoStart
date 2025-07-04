#!/data/data/com.termux/files/usr/bin/bash

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔍 CÔNG CỤ DEBUG & CHẨN ĐOÁN SHIZUKU${NC}"
echo -e "${CYAN}==========================================${NC}"
echo

# Kiểm tra môi trường Termux
echo -e "${BLUE}📱 MÔI TRƯỜNG TERMUX${NC}"
echo -e "Phiên bản Termux: $(termux-info | grep -oP '(?<=Termux-app version: ).*')"
echo -e "Phiên bản Android: $(getprop ro.build.version.release)"
echo -e "API level: $(getprop ro.build.version.sdk)"
echo -e "Kiến trúc: $(getprop ro.product.cpu.abi)"
echo

# Kiểm tra các file cần thiết
echo -e "${BLUE}📁 KIỂM TRA FILE${NC}"
FILES_TO_CHECK=(
    "/data/data/com.termux/files/usr/bin/shizuku"
    "/data/data/com.termux/files/usr/bin/rish"
    "/data/data/com.termux/files/home/rish_shizuku.dex"
)

for file in "${FILES_TO_CHECK[@]}"; do
    if [ -f "$file" ]; then
        if [ -x "$file" ]; then
            echo -e "✅ $file (có thể thực thi)"
        else
            echo -e "⚠️  $file (không thể thực thi)"
        fi
    else
        echo -e "❌ $file (thiếu)"
    fi
done

# Kiểm tra adbw_port
echo -e "\n${BLUE}🔧 CÔNG CỤ ADBW_PORT${NC}"
ADBW_LOCATIONS=(
    "$(pwd)/adbw_port"
    "$HOME/adbw_port"
    "$HOME/shizuku-autostart/adbw_port"
    "/data/data/com.termux/files/home/adbw_port"
)

FOUND_ADBW=false
for location in "${ADBW_LOCATIONS[@]}"; do
    if [ -f "$location" ]; then
        echo -e "✅ Tìm thấy adbw_port tại: $location"
        FOUND_ADBW=true
        ADBW_PATH="$location"
        break
    fi
done

if [ "$FOUND_ADBW" = false ]; then
    echo -e "❌ Không tìm thấy adbw_port ở các vị trí thông thường"
fi

# Kiểm tra ADB
echo -e "\n${BLUE}🔌 TRẠNG THÁI ADB${NC}"
if command -v adb >/dev/null 2>&1; then
    echo -e "✅ ADB đã cài đặt: $(adb version | head -1)"
    
    # Kiểm tra thiết bị ADB
    echo -e "\n🔍 Thiết bị ADB:"
    adb devices -l
    
    # Kiểm tra wireless debugging
    echo -e "\n📶 Trạng thái wireless debugging:"
    if adb shell settings get global adb_wifi_enabled 2>/dev/null | grep -q "1"; then
        echo -e "✅ Wireless debugging đã được bật"
    else
        echo -e "❌ Wireless debugging đã tắt"
    fi
else
    echo -e "❌ ADB chưa cài đặt"
fi

# Kiểm tra ứng dụng Shizuku
echo -e "\n${BLUE}📦 ỨNG DỤNG SHIZUKU${NC}"
if command -v adb >/dev/null 2>&1; then
    if adb shell pm list packages | grep -q "moe.shizuku.privileged.api"; then
        echo -e "✅ Ứng dụng Shizuku đã được cài đặt"
        
        # Lấy thông tin ứng dụng
        SHIZUKU_PATH=$(adb shell pm path moe.shizuku.privileged.api 2>/dev/null | sed 's/^package://')
        if [ -n "$SHIZUKU_PATH" ]; then
            echo -e "📁 Đường dẫn ứng dụng: $SHIZUKU_PATH"
            
            LIB_PATH=$(adb shell "echo \$(dirname \"$SHIZUKU_PATH\")/lib/*/libshizuku.so" 2>/dev/null)
            if [ -n "$LIB_PATH" ]; then
                echo -e "🔧 Đường dẫn thư viện: $LIB_PATH"
                
                # Kiểm tra thư viện có tồn tại không
                if adb shell test -f "$LIB_PATH" 2>/dev/null; then
                    echo -e "✅ libshizuku.so tồn tại"
                else
                    echo -e "❌ Không tìm thấy libshizuku.so"
                fi
            fi
        fi
    else
        echo -e "❌ Ứng dụng Shizuku chưa được cài đặt"
    fi
else
    echo -e "⚠️  Không thể kiểm tra (ADB không khả dụng)"
fi

# Kiểm tra dịch vụ Shizuku
echo -e "\n${BLUE}🚀 DỊCH VỤ SHIZUKU${NC}"
if command -v adb >/dev/null 2>&1 && adb devices | grep -q "device$"; then
    if adb shell pgrep -f shizuku >/dev/null 2>&1; then
        echo -e "✅ Dịch vụ Shizuku đang chạy"
        echo -e "📊 Thông tin tiến trình:"
        adb shell ps | grep shizuku || echo "Không có thông tin tiến trình chi tiết"
    else
        echo -e "❌ Dịch vụ Shizuku không chạy"
    fi
else
    echo -e "⚠️  Không thể kiểm tra (không có kết nối ADB)"
fi

# Kiểm tra kết nối mạng
echo -e "\n${BLUE}🌐 KẾT NỐI MẠNG${NC}"
if [ "$FOUND_ADBW" = true ] && [ -f "$ADBW_PATH" ]; then
    echo -e "🔍 Đang quét cổng ADB wireless..."
    cd "$(dirname "$ADBW_PATH")" || exit 1
    
    ADB_OUTPUT=$(./adbw_port _adb._tcp.local. 2>&1)
    if echo "$ADB_OUTPUT" | grep -q "ipv4:"; then
        IP_PORT=$(echo "$ADB_OUTPUT" | sed -n -e 's/.*ipv4: \([0-9.]*\), port: \([0-9]*\).*/\1:\2/p')
        echo -e "✅ Tìm thấy endpoint ADB: $IP_PORT"
    else
        echo -e "❌ Không tìm thấy endpoint ADB wireless"
        echo -e "📝 Output gốc:"
        echo "$ADB_OUTPUT"
    fi
else
    echo -e "⚠️  Không thể kiểm tra (adbw_port không khả dụng)"
fi

# Tóm tắt và khuyến nghị
echo -e "\n${CYAN}📋 KHUYẾN NGHỊ${NC}"
echo -e "${CYAN}===============${NC}"

if [ "$FOUND_ADBW" = false ]; then
    echo -e "🔧 Cài đặt công cụ adbw_port"
fi

if ! command -v adb >/dev/null 2>&1; then
    echo -e "🔧 Cài đặt ADB: pkg install android-tools"
fi

if ! adb shell pm list packages | grep -q "moe.shizuku.privileged.api" 2>/dev/null; then
    echo -e "🔧 Cài đặt ứng dụng Shizuku từ Play Store hoặc GitHub"
fi

if ! adb devices | grep -q "device$" 2>/dev/null; then
    echo -e "🔧 Bật wireless debugging và ghép nối thiết bị"
fi

echo -e "\n${GREEN}💡 Lệnh sửa lỗi nhanh:${NC}"
echo -e "  pkg install android-tools  # Cài đặt ADB"
echo -e "  ./copy.sh                  # Cài đặt lại scripts"
echo -e "  shizuku                    # Thử nghiệm Shizuku thủ công"

echo -e "\n${CYAN}🔗 Liên kết hữu ích:${NC}"
echo -e "  Shizuku GitHub: https://github.com/RikkaApps/Shizuku"
echo -e "  Hướng dẫn thiết lập: https://github.com/RikkaApps/Shizuku/discussions/462" 