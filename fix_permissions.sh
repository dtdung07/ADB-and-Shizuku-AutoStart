#!/data/data/com.termux/files/usr/bin/bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 FIXING PERMISSIONS...${NC}"

# Enable external apps in Termux (critical for adbw_port)
echo -e "${BLUE}📋 Enabling external apps in Termux...${NC}"
value="true"
key="allow-external-apps"
file="/data/data/com.termux/files/home/.termux/termux.properties"
mkdir -p "$(dirname "$file")"
chmod 700 "$(dirname "$file")"
if ! grep -E '^'"$key"'=.*' "$file" &>/dev/null; then
    [[ -s "$file" && ! -z "$(tail -c 1 "$file")" ]] && newline=$'\n' || newline=""
    echo "$newline$key=$value" >> "$file"
    echo -e "✅ Enabled allow-external-apps"
else
    if ! grep -E '^'"$key"'=true' "$file" &>/dev/null; then
        sed -i'' -E 's/^'"$key"'=.*/'"$key=$value"'/' "$file"
        echo -e "✅ Updated allow-external-apps=true"
    else
        echo -e "✅ allow-external-apps already enabled"
    fi
fi

# Fix permissions for all binary files
chmod +x adbw_port adbw_port_arm.bin adbw_port_arm64.bin 2>/dev/null

# Fix permissions for scripts
chmod +x copy.sh debug_shizuku.sh 2>/dev/null

# Check results
echo -e "${BLUE}📋 Permission status:${NC}"
for file in adbw_port adbw_port_arm.bin adbw_port_arm64.bin copy.sh debug_shizuku.sh; do
    if [ -f "$file" ]; then
        if [ -x "$file" ]; then
            echo -e "✅ $file"
        else
            echo -e "❌ $file (still not executable)"
        fi
    else
        echo -e "⚠️  $file (not found)"
    fi
done

echo -e "\n${GREEN}✅ Permission fix completed!${NC}"
echo -e "${BLUE}⚠️  IMPORTANT: Please restart Termux app for external apps setting to take effect!${NC}"
echo -e "${BLUE}💡 After restart, try: shizuku${NC}" 