#!/data/data/com.termux/files/usr/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔍 ADB CONNECTION DEBUGGER${NC}"
echo -e "${CYAN}=========================${NC}"
echo

# Get the device info that adbw_port found
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADBW_PORT_SCRIPT=""

# Find adbw_port
for path in "${SCRIPT_DIR}" "${HOME}" "${HOME}/shizuku-autostart" "/data/data/com.termux/files/home" "$(pwd)"; do
    if [ -f "${path}/adbw_port" ]; then
        ADBW_PORT_SCRIPT="${path}/adbw_port"
        break
    fi
done

if [ -z "$ADBW_PORT_SCRIPT" ] || [ ! -f "$ADBW_PORT_SCRIPT" ]; then
    echo -e "${RED}ERROR: adbw_port not found!${NC}"
    exit 1
fi

cd "$(dirname "$ADBW_PORT_SCRIPT")" || exit 1

echo -e "${BLUE}📱 SCANNING FOR ADB WIRELESS...${NC}"
ADB_OUTPUT=$(./adbw_port _adb._tcp.local. 2>&1)
echo "Raw output:"
echo "$ADB_OUTPUT"
echo

read ip port < <(echo "$ADB_OUTPUT" | sed -n -e 's/.*ipv4: \([0-9.]*\), port: \([0-9]*\).*/\1 \2/p')
device="${ip}:${port}"

if [[ -z "$ip" || -z "$port" ]]; then
    echo -e "${RED}❌ No ADB device found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Found device: $device${NC}"
echo

# Check if ADB is available
echo -e "${BLUE}🔧 ADB STATUS CHECK${NC}"
if command -v adb >/dev/null 2>&1; then
    echo -e "✅ ADB command available"
    adb version
else
    echo -e "${RED}❌ ADB command not found${NC}"
    echo -e "${YELLOW}Installing ADB...${NC}"
    pkg install android-tools
    if command -v adb >/dev/null 2>&1; then
        echo -e "${GREEN}✅ ADB installed successfully${NC}"
    else
        echo -e "${RED}❌ Failed to install ADB${NC}"
        exit 1
    fi
fi

echo

# Check ADB server status
echo -e "${BLUE}🖥️  ADB SERVER STATUS${NC}"
adb kill-server
sleep 1
adb start-server
echo

# Try to connect with detailed output
echo -e "${BLUE}🔗 TESTING ADB CONNECTION${NC}"
echo "Connecting to: $device"
adb connect "$device"
echo

# Check connection status
echo -e "${BLUE}📋 ADB DEVICES LIST${NC}"
adb devices -l
echo

# Test shell access
echo -e "${BLUE}🐚 TESTING SHELL ACCESS${NC}"
echo "Testing: adb -s $device shell echo 'Hello from ADB'"
if adb -s "$device" shell echo 'Hello from ADB' 2>/dev/null; then
    echo -e "${GREEN}✅ Shell access working!${NC}"
else
    echo -e "${RED}❌ Shell access failed${NC}"
    
    echo -e "\n${YELLOW}🔧 TROUBLESHOOTING STEPS:${NC}"
    echo "1. Check if wireless debugging is still enabled on your device"
    echo "2. Verify you're on the same WiFi network"
    echo "3. Try pairing again in Developer Options"
    echo "4. The port might have changed - wireless debugging ports are dynamic"
fi

echo

# Show device settings (if connected)
echo -e "${BLUE}⚙️  DEVICE ADB SETTINGS${NC}"
if adb -s "$device" shell id >/dev/null 2>&1; then
    echo "ADB WiFi enabled: $(adb -s "$device" shell settings get global adb_wifi_enabled 2>/dev/null || echo 'unknown')"
    echo "Developer options: $(adb -s "$device" shell settings get global development_settings_enabled 2>/dev/null || echo 'unknown')"
    echo "USB debugging: $(adb -s "$device" shell settings get global adb_enabled 2>/dev/null || echo 'unknown')"
else
    echo -e "${YELLOW}Cannot check - device not properly connected${NC}"
fi

echo
echo -e "${CYAN}💡 QUICK FIXES TO TRY:${NC}"
echo "1. On your Android device:"
echo "   Settings → Developer Options → Wireless Debugging → Turn OFF then ON"
echo "2. Pair again if needed"
echo "3. Run this debug script again to see new port"
echo "4. Or try: adb connect $device" 