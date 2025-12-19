#!/bin/bash
#
# Home Assistant iOS - Unused L10n Strings Finder (Shell Wrapper)
# 
# This is a simple shell wrapper for the Python script that analyzes unused L10n strings.
# Use this if you prefer running shell scripts or want to add additional automation.
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/find_unused_l10n_strings.py"

echo -e "${BLUE}🏠 Home Assistant iOS - Unused L10n Strings Finder${NC}"
echo -e "${BLUE}====================================================${NC}\n"

# Check if Python script exists
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo -e "${RED}❌ Error: Python script not found at $PYTHON_SCRIPT${NC}"
    exit 1
fi

# Check if we're in the right directory (look for HomeAssistant.xcodeproj)
if [ ! -d "HomeAssistant.xcodeproj" ]; then
    echo -e "${YELLOW}⚠️  Warning: HomeAssistant.xcodeproj not found in current directory${NC}"
    echo -e "${YELLOW}   Make sure you're running this from the Home Assistant iOS project root${NC}\n"
fi

# Run the Python script
echo -e "${GREEN}🚀 Starting analysis...${NC}\n"

# Pass all arguments to the Python script
python3 "$PYTHON_SCRIPT" "$@"

# Check if analysis was successful
if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✅ Analysis completed successfully!${NC}"
    echo -e "\n${BLUE}📋 Next steps:${NC}"
    echo -e "   1. Review the generated reports"
    echo -e "   2. Verify the 'truly unused' strings are safe to remove"
    echo -e "   3. Remove unused strings from the localization files"
    echo -e "   4. Regenerate Strings.swift using SwiftGen"
    echo -e "\n${YELLOW}💡 Tip: Always test your app thoroughly after removing strings!${NC}"
else
    echo -e "\n${RED}❌ Analysis failed. Check the error messages above.${NC}"
    exit 1
fi