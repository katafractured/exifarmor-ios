#!/usr/bin/env bash
set -euo pipefail
ERRORS=0

# 1. Lint all .entitlements files
for f in $(find . -name "*.entitlements" -not -path "./.git/*"); do
    if ! plutil -lint "$f" > /dev/null 2>&1; then
        echo "ERROR: Malformed entitlements: $f"
        plutil -lint "$f"
        ERRORS=$((ERRORS+1))
    fi
done

# 2. Check all .xcprivacy files are valid plists
for f in $(find . -name "*.xcprivacy" -not -path "./.git/*"); do
    if ! plutil -lint "$f" > /dev/null 2>&1; then
        echo "ERROR: Malformed PrivacyInfo: $f"
        ERRORS=$((ERRORS+1))
    fi
done

# 3. Check every app/extension target has a PrivacyInfo.xcprivacy
# Find all Info.plist-containing directories (each is a target bundle)
for dir in $(find . -name "Info.plist" -not -path "./.git/*" -not -path "*/build/*" | xargs -I{} dirname {}); do
    if [ ! -f "$dir/PrivacyInfo.xcprivacy" ]; then
        echo "WARNING: No PrivacyInfo.xcprivacy in $dir"
    fi
done

# 4. Lint all Info.plist files
for f in $(find . -name "Info.plist" -not -path "./.git/*" -not -path "*/build/*"); do
    if ! plutil -lint "$f" > /dev/null 2>&1; then
        echo "ERROR: Malformed Info.plist: $f"
        ERRORS=$((ERRORS+1))
    fi
done

if [ $ERRORS -gt 0 ]; then
    echo "FAILED: $ERRORS error(s) found. Fix before submitting."
    exit 1
fi
echo "OK: All binary validation checks passed."
