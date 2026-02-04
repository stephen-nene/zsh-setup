#!/usr/bin/env bash

# Test script for automated validation of install-zsh.sh
# This creates a fake interactive environment to test plugin selection

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

TEST_RESULTS=0

test_case() {
  local name=$1
  local input=$2
  local description=$3

  echo ""
  echo -e "${BLUE}Test: $name${NC}"
  echo "Description: $description"
  echo "Input: $input"
  echo "---"

  # Run script with piped input and capture output
  if echo "$input" | bash /tmp/install-zsh.sh > /tmp/test_output.log 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    # Show relevant log lines
    grep -E "\[INFO\]|\[✓\]|\[WARN\]" /tmp/test_output.log | head -10 || true
  else
    echo -e "${RED}✗ FAILED${NC}"
    TEST_RESULTS=$((TEST_RESULTS + 1))
    # Show error
    tail -20 /tmp/test_output.log
  fi
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Automated Test Suite${NC}"
echo -e "${BLUE}========================================${NC}"

# Test 1: Select no plugins
test_case "no-plugins" "none" \
  "Test selecting no plugins (basic install only)"

# Test 2: Select all plugins
test_case "all-plugins" "all" \
  "Test selecting all plugins"

# Test 3: Select specific plugins
test_case "specific-plugins" "1,3" \
  "Test selecting specific plugins by number"

# Test 4: Dry run with mixed selection
test_case "mixed-selection" "1,2,4" \
  "Test selecting zsh-autosuggestions, zsh-syntax-highlighting, zsh-autocomplete"

# Summary
echo ""
echo -e "${BLUE}========================================${NC}"
if [ $TEST_RESULTS -eq 0 ]; then
  echo -e "${GREEN}All tests passed!${NC}"
else
  echo -e "${RED}$TEST_RESULTS test(s) failed${NC}"
fi
echo -e "${BLUE}========================================${NC}"

exit $TEST_RESULTS
