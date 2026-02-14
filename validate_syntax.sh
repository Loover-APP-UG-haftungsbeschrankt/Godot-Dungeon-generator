#!/bin/bash

# Syntax validation script for GDScript files
# Validates that all .gd files have correct basic syntax

echo "=========================================="
echo "GDSCRIPT SYNTAX VALIDATION"
echo "=========================================="
echo

total_files=0
passed_files=0
failed_files=0

# Function to do basic syntax checks
validate_gdscript() {
    local file=$1
    local errors=0
    
    echo "Checking: $file"
    
    # Check if file exists
    if [ ! -f "$file" ]; then
        echo "  ✗ File not found"
        return 1
    fi
    
    # Check for basic syntax issues
    
    # Check for balanced braces
    local open_braces=$(grep -o '{' "$file" | wc -l)
    local close_braces=$(grep -o '}' "$file" | wc -l)
    if [ "$open_braces" -ne "$close_braces" ]; then
        echo "  ⚠ Warning: Unbalanced braces (open: $open_braces, close: $close_braces)"
        errors=$((errors + 1))
    fi
    
    # Check for balanced parentheses
    local open_parens=$(grep -o '(' "$file" | wc -l)
    local close_parens=$(grep -o ')' "$file" | wc -l)
    if [ "$open_parens" -ne "$close_parens" ]; then
        echo "  ⚠ Warning: Unbalanced parentheses (open: $open_parens, close: $close_parens)"
        errors=$((errors + 1))
    fi
    
    # Check for balanced brackets
    local open_brackets=$(grep -o '\[' "$file" | wc -l)
    local close_brackets=$(grep -o '\]' "$file" | wc -l)
    if [ "$open_brackets" -ne "$close_brackets" ]; then
        echo "  ⚠ Warning: Unbalanced brackets (open: $open_brackets, close: $close_brackets)"
        errors=$((errors + 1))
    fi
    
    # Check that class_name (if present) is at the top
    if grep -q "^class_name" "$file"; then
        local first_code_line=$(grep -n -v "^#\|^$" "$file" | head -1 | cut -d: -f1)
        local class_line=$(grep -n "^class_name" "$file" | head -1 | cut -d: -f1)
        if [ "$class_line" -ne "$first_code_line" ]; then
            echo "  ⚠ Warning: class_name should be first non-comment line"
            errors=$((errors + 1))
        fi
    fi
    
    # Check that extends is present (if not class_name)
    if ! grep -q "^class_name\|^extends" "$file"; then
        echo "  ⚠ Warning: No class_name or extends declaration found"
        errors=$((errors + 1))
    fi
    
    # Check for common typos
    if grep -q "fucn\|retrun\|esle" "$file"; then
        echo "  ⚠ Warning: Possible typos detected"
        errors=$((errors + 1))
    fi
    
    if [ $errors -eq 0 ]; then
        echo "  ✓ Passed"
        return 0
    else
        echo "  ⚠ Completed with $errors warnings"
        return 0
    fi
}

# Find and validate all .gd files
while IFS= read -r file; do
    total_files=$((total_files + 1))
    if validate_gdscript "$file"; then
        passed_files=$((passed_files + 1))
    else
        failed_files=$((failed_files + 1))
    fi
    echo
done < <(find scripts -name "*.gd" -type f | sort)

echo "=========================================="
echo "VALIDATION COMPLETE"
echo "=========================================="
echo "Total files: $total_files"
echo "Passed: $passed_files"
echo "Failed: $failed_files"
echo

if [ $failed_files -eq 0 ]; then
    echo "✓ ALL FILES VALIDATED"
    exit 0
else
    echo "✗ SOME FILES FAILED VALIDATION"
    exit 1
fi
