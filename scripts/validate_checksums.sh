#!/bin/bash

# Evidence Integrity Validation Script
# Validates current file checksums against recorded values in evidence_integrity_verification.md

echo "=========================================="
echo "EVIDENCE INTEGRITY VALIDATION"
echo "=========================================="
echo "Date: $(date)"
echo "System: $(uname -a)"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
TOTAL_FILES=0
PASSED_FILES=0
FAILED_FILES=0
MISSING_FILES=0

# Work from current directory (should be project root)

echo "Validating evidence integrity against recorded checksums..."
echo ""

# Function to extract checksums from evidence_integrity_verification.md
extract_recorded_checksums() {
    if [ ! -f "evidence_integrity_verification.md" ]; then
        echo -e "${RED}ERROR: evidence_integrity_verification.md not found!${NC}"
        echo "Make sure you're running this script from the project root directory."
        exit 1
    fi
    
    # Extract file entries with their checksums
    grep -E "^\*\*File\*\*: \`.*\`$" evidence_integrity_verification.md | while read file_line; do
        # Extract filename from **File**: `filename`
        FILENAME=$(echo "$file_line" | sed -E 's/\*\*File\*\*: `(.+)`$/\1/')
        
        # Read next few lines to get MD5 and SHA256
        LINE_NUM=$(grep -n "^\*\*File\*\*: \`$FILENAME\`$" evidence_integrity_verification.md | cut -d: -f1)
        
        if [ ! -z "$LINE_NUM" ]; then
            # Get MD5 (should be 2 lines after the File line)
            MD5_LINE=$((LINE_NUM + 1))
            RECORDED_MD5=$(sed -n "${MD5_LINE}p" evidence_integrity_verification.md | sed -E 's/- \*\*MD5\*\*: (.+)$/\1/')
            
            # Get SHA256 (should be 3 lines after the File line)
            SHA256_LINE=$((LINE_NUM + 2))
            RECORDED_SHA256=$(sed -n "${SHA256_LINE}p" evidence_integrity_verification.md | sed -E 's/- \*\*SHA256\*\*: (.+)$/\1/')
            
            # Get file size (should be 4 lines after the File line)
            SIZE_LINE=$((LINE_NUM + 3))
            RECORDED_SIZE=$(sed -n "${SIZE_LINE}p" evidence_integrity_verification.md | sed -E 's/- \*\*Size\*\*: (.+) bytes$/\1/')
            
            echo "$FILENAME|$RECORDED_MD5|$RECORDED_SHA256|$RECORDED_SIZE"
        fi
    done
}

# Create temporary file with recorded checksums
TEMP_RECORDED="/tmp/recorded_checksums_$(date +%s).txt"
extract_recorded_checksums > "$TEMP_RECORDED"

echo "Found $(wc -l < "$TEMP_RECORDED") files in verification document"
echo ""

# Validate each file
while IFS='|' read -r filename recorded_md5 recorded_sha256 recorded_size; do
    if [ -z "$filename" ]; then
        continue
    fi
    
    TOTAL_FILES=$((TOTAL_FILES + 1))
    echo "Validating: $filename"
    
    # Check if file exists
    if [ ! -f "$filename" ]; then
        echo -e "  ${RED}✗ MISSING${NC} - File not found"
        MISSING_FILES=$((MISSING_FILES + 1))
        echo ""
        continue
    fi
    
    # Generate current checksums
    CURRENT_MD5=$(md5 -q "$filename" 2>/dev/null)
    CURRENT_SHA256=$(shasum -a 256 "$filename" 2>/dev/null | cut -d' ' -f1)
    CURRENT_SIZE=$(stat -f "%z" "$filename" 2>/dev/null)
    
    # Validate MD5
    MD5_MATCH=false
    if [ "$CURRENT_MD5" = "$recorded_md5" ]; then
        MD5_MATCH=true
    fi
    
    # Validate SHA256
    SHA256_MATCH=false
    if [ "$CURRENT_SHA256" = "$recorded_sha256" ]; then
        SHA256_MATCH=true
    fi
    
    # Validate Size
    SIZE_MATCH=false
    if [ "$CURRENT_SIZE" = "$recorded_size" ]; then
        SIZE_MATCH=true
    fi
    
    # Overall validation
    if [ "$MD5_MATCH" = true ] && [ "$SHA256_MATCH" = true ] && [ "$SIZE_MATCH" = true ]; then
        echo -e "  ${GREEN}✓ PASS${NC} - All checksums match"
        PASSED_FILES=$((PASSED_FILES + 1))
    else
        echo -e "  ${RED}✗ FAIL${NC} - Checksum mismatch detected"
        FAILED_FILES=$((FAILED_FILES + 1))
        
        # Show detailed comparison
        if [ "$MD5_MATCH" = false ]; then
            echo -e "    ${YELLOW}MD5:${NC}"
            echo "      Expected: $recorded_md5"
            echo "      Current:  $CURRENT_MD5"
        fi
        
        if [ "$SHA256_MATCH" = false ]; then
            echo -e "    ${YELLOW}SHA256:${NC}"
            echo "      Expected: $recorded_sha256"
            echo "      Current:  $CURRENT_SHA256"
        fi
        
        if [ "$SIZE_MATCH" = false ]; then
            echo -e "    ${YELLOW}SIZE:${NC}"
            echo "      Expected: $recorded_size bytes"
            echo "      Current:  $CURRENT_SIZE bytes"
        fi
    fi
    
    echo ""
    
done < "$TEMP_RECORDED"

# Cleanup
rm "$TEMP_RECORDED"

echo "=========================================="
echo "VALIDATION SUMMARY"
echo "=========================================="
echo "Total Files Checked: $TOTAL_FILES"
echo -e "Passed: ${GREEN}$PASSED_FILES${NC}"
echo -e "Failed: ${RED}$FAILED_FILES${NC}"
echo -e "Missing: ${YELLOW}$MISSING_FILES${NC}"
echo ""

# Overall result
if [ $FAILED_FILES -eq 0 ] && [ $MISSING_FILES -eq 0 ]; then
    echo -e "${GREEN}✓ EVIDENCE INTEGRITY VERIFIED${NC}"
    echo "All evidence files maintain their original integrity."
    echo "Evidence is suitable for legal proceedings."
    exit 0
else
    echo -e "${RED}✗ EVIDENCE INTEGRITY COMPROMISED${NC}"
    if [ $FAILED_FILES -gt 0 ]; then
        echo "WARNING: $FAILED_FILES file(s) have been modified since verification."
    fi
    if [ $MISSING_FILES -gt 0 ]; then
        echo "WARNING: $MISSING_FILES file(s) are missing from the evidence collection."
    fi
    echo ""
    echo "RECOMMENDED ACTIONS:"
    echo "1. Do not modify any files"
    echo "2. Document all discrepancies"
    echo "3. Contact legal counsel immediately"
    echo "4. Consider professional forensic analysis"
    exit 1
fi