#!/data/data/com.termux/files/usr/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔍 SHIZUKU DEBUG & DIAGNOSTIC TOOL${NC}"
echo -e "${CYAN}====================================${NC}"
echo

# Check Termux environment
echo -e "${BLUE}📱 TERMUX ENVIRONMENT${NC}"
echo -e "Termux version: $(termux-info | grep -oP '(?<=Termux-app version: ).*')"
echo -e "Android version: $(getprop ro.build.version.release)"
echo -e "API level: $(getprop ro.build.version.sdk)"
echo -e "Architecture: $(getprop ro.product.cpu.abi)"
echo

# Check required files
echo -e "${BLUE}📁 FILE CHECKS${NC}"
FILES_TO_CHECK=(
    "/data/data/com.termux/files/usr/bin/shizuku"
    "/data/data/com.termux/files/usr/bin/rish"
    "/data/data/com.termux/files/home/rish_shizuku.dex"
)

for file in "${FILES_TO_CHECK[@]}"; do
    if [ -f "$file" ]; then
        if [ -x "$file" ]; then
            echo -e "✅ $file (executable)"
        else
            echo -e "⚠️  $file (not executable)"
        fi
    else
        echo -e "❌ $file (missing)"
    fi
done

# Check for adbw_port
echo -e "\n${BLUE}🔧 ADBW_PORT TOOL${NC}"
ADBW_LOCATIONS=(
    "$(pwd)/adbw_port"
    "$HOME/adbw_port"
    "$HOME/shizuku-autostart/adbw_port"
    "/data/data/com.termux/files/home/adbw_port"
)

FOUND_ADBW=false
for location in "${ADBW_LOCATIONS[@]}"; do
    if [ -f "$location" ]; then
        echo -e "✅ Found adbw_port at: $location"
        FOUND_ADBW=true
        ADBW_PATH="$location"
        break
    fi
done

if [ "$FOUND_ADBW" = false ]; then
    echo -e "❌ adbw_port not found in common locations"
fi

# Check ADB
echo -e "\n${BLUE}🔌 ADB STATUS${NC}"
if command -v adb >/dev/null 2>&1; then
    echo -e "✅ ADB installed: $(adb version | head -1)"
    
    # Check ADB devices
    echo -e "\n🔍 ADB Devices:"
    adb devices -l
    
    # Check wireless debugging
    echo -e "\n📶 Wireless debugging status:"
    if adb shell settings get global adb_wifi_enabled 2>/dev/null | grep -q "1"; then
        echo -e "✅ Wireless debugging is enabled"
    else
        echo -e "❌ Wireless debugging is disabled"
    fi
else
    echo -e "❌ ADB not installed"
fi

# Check Shizuku app
echo -e "\n${BLUE}📦 SHIZUKU APP${NC}"
if command -v adb >/dev/null 2>&1; then
    if adb shell pm list packages | grep -q "moe.shizuku.privileged.api"; then
        echo -e "✅ Shizuku app is installed"
        
        # Get app info
        SHIZUKU_PATH=$(adb shell pm path moe.shizuku.privileged.api 2>/dev/null | sed 's/^package://')
        if [ -n "$SHIZUKU_PATH" ]; then
            echo -e "📁 App path: $SHIZUKU_PATH"
            
            LIB_PATH=$(adb shell "echo \$(dirname \"$SHIZUKU_PATH\")/lib/*/libshizuku.so" 2>/dev/null)
            if [ -n "$LIB_PATH" ]; then
                echo -e "🔧 Library path: $LIB_PATH"
                
                # Check if library exists
                if adb shell test -f "$LIB_PATH" 2>/dev/null; then
                    echo -e "✅ libshizuku.so exists"
                else
                    echo -e "❌ libshizuku.so not found"
                fi
            fi
        fi
    else
        echo -e "❌ Shizuku app is not installed"
    fi
else
    echo -e "⚠️  Cannot check (ADB not available)"
fi

# Check Shizuku service
echo -e "\n${BLUE}🚀 SHIZUKU SERVICE${NC}"
if command -v adb >/dev/null 2>&1 && adb devices | grep -q "device$"; then
    if adb shell pgrep -f shizuku >/dev/null 2>&1; then
        echo -e "✅ Shizuku service is running"
        echo -e "📊 Process info:"
        adb shell ps | grep shizuku || echo "No detailed process info available"
    else
        echo -e "❌ Shizuku service is not running"
    fi
else
    echo -e "⚠️  Cannot check (no ADB connection)"
fi

# Network connectivity test
echo -e "\n${BLUE}🌐 NETWORK CONNECTIVITY${NC}"
if [ "$FOUND_ADBW" = true ] && [ -f "$ADBW_PATH" ]; then
    echo -e "🔍 Scanning for ADB wireless ports..."
    cd "$(dirname "$ADBW_PATH")" || exit 1
    
    ADB_OUTPUT=$(./adbw_port _adb._tcp.local. 2>&1)
    if echo "$ADB_OUTPUT" | grep -q "ipv4:"; then
        IP_PORT=$(echo "$ADB_OUTPUT" | sed -n -e 's/.*ipv4: \([0-9.]*\), port: \([0-9]*\).*/\1:\2/p')
        echo -e "✅ Found ADB endpoint: $IP_PORT"
    else
        echo -e "❌ No ADB wireless endpoint found"
        echo -e "📝 Raw output:"
        echo "$ADB_OUTPUT"
    fi
else
    echo -e "⚠️  Cannot test (adbw_port not available)"
fi

# Summary and recommendations
echo -e "\n${CYAN}📋 RECOMMENDATIONS${NC}"
echo -e "${CYAN}==================${NC}"

if [ "$FOUND_ADBW" = false ]; then
    echo -e "🔧 Install adbw_port tool"
fi

if ! command -v adb >/dev/null 2>&1; then
    echo -e "🔧 Install ADB: pkg install android-tools"
fi

if ! adb shell pm list packages | grep -q "moe.shizuku.privileged.api" 2>/dev/null; then
    echo -e "🔧 Install Shizuku app from Play Store or GitHub"
fi

if ! adb devices | grep -q "device$" 2>/dev/null; then
    echo -e "🔧 Enable wireless debugging and pair device"
fi

echo -e "\n${GREEN}💡 Quick fix commands:${NC}"
echo -e "  pkg install android-tools  # Install ADB"
echo -e "  ./copy.sh                  # Reinstall scripts"
echo -e "  shizuku                    # Test Shizuku manually"

echo -e "\n${CYAN}🔗 Useful links:${NC}"
echo -e "  Shizuku GitHub: https://github.com/RikkaApps/Shizuku"
echo -e "  Setup guide: https://github.com/RikkaApps/Shizuku/discussions/462" 