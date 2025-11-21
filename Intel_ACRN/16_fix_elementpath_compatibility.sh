#!/bin/bash
#
# Script: 16_fix_elementpath_compatibility.sh
# Purpose: Patch ACRN code to work with newer elementpath versions (no TypedElement)
# Usage: sudo ./16_fix_elementpath_compatibility.sh

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ACRN_DIR="$PROJECT_ROOT/acrn-hypervisor"

echo "========================================"
echo "Fix Elementpath Compatibility"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

if [ ! -d "$ACRN_DIR" ]; then
    echo "❌ ACRN source not found: $ACRN_DIR"
    echo "   Run 04_download_acrn_3.3.sh first"
    exit 1
fi

ELEMENTPATH_OVERLAY="$ACRN_DIR/misc/config_tools/scenario_config/elementpath_overlay.py"

if [ ! -f "$ELEMENTPATH_OVERLAY" ]; then
    echo "❌ elementpath_overlay.py not found: $ELEMENTPATH_OVERLAY"
    exit 1
fi

echo "Found elementpath_overlay.py: $ELEMENTPATH_OVERLAY"
echo ""

# Check if already patched
if grep -q "# PATCHED: TypedElement compatibility" "$ELEMENTPATH_OVERLAY" 2>/dev/null; then
    echo "✓ File already patched"
    exit 0
fi

# Backup original file
BACKUP_FILE="${ELEMENTPATH_OVERLAY}.backup.$(date +%Y%m%d-%H%M%S)"
cp "$ELEMENTPATH_OVERLAY" "$BACKUP_FILE"
echo "✓ Backed up original file to: $BACKUP_FILE"
echo ""

# Check current elementpath version
ELEMENTPATH_VERSION=$(python3 -c "import elementpath; print(elementpath.__version__)" 2>/dev/null || echo "unknown")
echo "Current elementpath version: $ELEMENTPATH_VERSION"
echo ""

# Patch the file to handle both old and new elementpath
echo "Applying compatibility patch..."

# Use Python to apply the patch
python3 << EOF
import sys
import re

file_path = "$ELEMENTPATH_OVERLAY"

with open(file_path, 'r') as f:
    content = f.read()

# Check if TypedElement is used
if 'TypedElement' not in content:
    print("No TypedElement usage found - no patch needed")
    sys.exit(0)

# Replace isinstance(op, elementpath.TypedElement) with a compatible check
# The new check looks for objects that have 'name' and 'select' attributes
# which are characteristic of XPath token objects
old_pattern = r'isinstance\(op,\s*elementpath\.TypedElement\)'
new_replacement = '(hasattr(op, "name") and hasattr(op, "select") and not isinstance(op, (str, int, float, bool, type(None))))'

# Use re.sub with the pattern and replacement
content = re.sub(old_pattern, new_replacement, content)

# Add compatibility comment if not present
if '# PATCHED: TypedElement compatibility' not in content:
    lines = content.split('\n')
    for i, line in enumerate(lines):
        if 'import elementpath' in line and i + 1 < len(lines):
            lines.insert(i + 1, '# PATCHED: TypedElement compatibility')
            lines.insert(i + 2, '# This patch allows ACRN to work with elementpath >= 4.0.0 (no TypedElement)')
            break
    content = '\n'.join(lines)

with open(file_path, 'w') as f:
    f.write(content)

print("✓ Patch applied successfully")
EOF

# Verify patch
if grep -q "hasattr(op" "$ELEMENTPATH_OVERLAY" || grep -q "PATCHED" "$ELEMENTPATH_OVERLAY"; then
    echo "✓ Patch verification passed"
else
    echo "⚠️  Patch may not have been applied correctly"
    echo "   You may need to manually edit: $ELEMENTPATH_OVERLAY"
    echo "   Look for line with: isinstance(op, elementpath.TypedElement)"
    echo "   Replace with: hasattr(op, 'name') and hasattr(op, 'select')"
fi

echo ""
echo "========================================"
echo "✓ Elementpath Compatibility Fix Applied"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Install compatible packages:"
echo "   sudo pip3 install --break-system-packages 'elementpath>=4.0.0' 'xmlschema>=2.0.0'"
echo ""
echo "2. Rebuild ACRN:"
echo "   sudo ./06_build_acrn.sh generic_board shared"
echo ""

