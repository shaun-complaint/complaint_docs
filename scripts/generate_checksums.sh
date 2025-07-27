#!/bin/bash

# Evidence Integrity Verification Script
# Generates MD5/SHA256 checksums for all evidence files

echo "Generating checksums for all evidence files..."
echo "Date: $(date)"
echo "System: $(uname -a)"
echo ""

# Create temporary file for results
TEMP_FILE="/tmp/checksums_$(date +%s).txt"

# Find all evidence files
find . -type f \( -name "*.png" -o -name "*.jpeg" -o -name "*.jpg" -o -name "*.md" \) ! -name "evidence_integrity_verification.md" ! -name "generate_checksums.sh" | sort | while read file; do
    echo "Processing: $file"
    
    # Get file info
    SIZE=$(stat -f "%z" "$file")
    MODIFIED=$(stat -f "%Sm" "$file")
    
    # Generate hashes
    MD5_HASH=$(md5 -q "$file")
    SHA256_HASH=$(shasum -a 256 "$file" | cut -d' ' -f1)
    
    # Output results
    echo "File: $file"
    echo "MD5: $MD5_HASH"
    echo "SHA256: $SHA256_HASH"
    echo "Size: $SIZE bytes"
    echo "Modified: $MODIFIED"
    echo "---"
    
    # Save to temp file for later processing
    echo "$file|$MD5_HASH|$SHA256_HASH|$SIZE|$MODIFIED" >> "$TEMP_FILE"
done

echo "Checksums generated. Results saved to: $TEMP_FILE"
echo "Use this data to update evidence_integrity_verification.md"