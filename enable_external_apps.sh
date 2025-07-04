#!/data/data/com.termux/files/usr/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 TERMUX EXTERNAL APPS ENABLER${NC}"
echo -e "${BLUE}================================${NC}"
echo

# Enable external apps setting
echo -e "${BLUE}📋 Enabling allow-external-apps in Termux...${NC}"

value="true"
key="allow-external-apps"
file="/data/data/com.termux/files/home/.termux/termux.properties"

# Create .termux directory if not exists
mkdir -p "$(dirname "$file")"
chmod 700 "$(dirname "$file")"

# Check if setting already exists
if ! grep -E '^'"$key"'=.*' "$file" &>/dev/null; then
    # Add new setting
    [[ -s "$file" && ! -z "$(tail -c 1 "$file")" ]] && newline=$'\n' || newline=""
    echo "$newline$key=$value" >> "$file"
    echo -e "${GREEN}✅ Added allow-external-apps=true to termux.properties${NC}"
    CHANGED=true
else
    # Check if value is correct
    if ! grep -E '^'"$key"'=true' "$file" &>/dev/null; then
        # Update existing setting
        sed -i'' -E 's/^'"$key"'=.*/'"$key=$value"'/' "$file"
        echo -e "${GREEN}✅ Updated allow-external-apps=true in termux.properties${NC}"
        CHANGED=true
    else
        echo -e "${GREEN}✅ allow-external-apps is already enabled${NC}"
        CHANGED=false
    fi
fi

# Show current config
echo -e "\n${BLUE}📄 Current Termux configuration:${NC}"
if [ -f "$file" ]; then
    cat "$file"
else
    echo -e "${YELLOW}No termux.properties file found${NC}"
fi

echo

# Show next steps
if [ "$CHANGED" = true ]; then
    echo -e "${YELLOW}⚠️  IMPORTANT NEXT STEPS:${NC}"
    echo -e "${YELLOW}1. Close Termux app completely${NC}"
    echo -e "${YELLOW}2. Reopen Termux app${NC}"
    echo -e "${YELLOW}3. This is required for the setting to take effect${NC}"
    echo
    echo -e "${BLUE}💡 After restart, you can run external binaries like adbw_port${NC}"
else
    echo -e "${GREEN}✅ No restart needed - setting was already active${NC}"
fi

echo -e "\n${BLUE}🔗 More info: https://wiki.termux.com/wiki/Termux.properties${NC}" 