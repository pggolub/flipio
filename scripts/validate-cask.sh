#!/bin/bash

# Validate Homebrew Cask Formula
# Runs brew style and brew audit on the cask

set -e

CASK_FILE="cask/flipio.rb"

if [ ! -f "$CASK_FILE" ]; then
    echo "Error: Cask file not found: $CASK_FILE"
    exit 1
fi

echo "Validating Homebrew Cask formula..."
echo ""

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Error: Homebrew is not installed"
    exit 1
fi

# Run brew style
echo "Running brew style..."
if brew style --fix "$CASK_FILE"; then
    echo "✓ Style check passed"
else
    echo "✗ Style check failed"
    exit 1
fi

echo ""

echo "✓ Style validation passed!"
echo ""
echo "Note: Full audit (brew audit --cask --online flipio) requires the cask"
echo "to be in a tap. After setting up your tap, run:"
echo "  brew tap pavel-golub/flipio"
echo "  brew audit --cask --online flipio"

echo ""
echo "✓ All validation checks passed!"
