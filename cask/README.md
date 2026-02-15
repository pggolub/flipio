# Flipio Homebrew Cask

This directory contains the Homebrew Cask formula for distributing Flipio.

## Files

- **flipio.rb** - The Homebrew Cask formula

## For Users

To install Flipio via Homebrew:

```bash
brew tap pavel-golub/flipio
brew install --cask flipio
```

## For Maintainers

See [HOMEBREW_RELEASE.md](../HOMEBREW_RELEASE.md) for complete release instructions.

### Quick Update Guide

When releasing a new version:

1. Build and create ZIP of the new release
2. Calculate SHA256: `./scripts/calculate-sha256.sh Flipio-X.Y.Z.zip`
3. Upload ZIP to GitHub Releases
4. Update this formula:
   ```ruby
   version "X.Y.Z"        # Update version
   sha256 "abc123..."     # Update with calculated SHA256
   ```
5. Validate: `./scripts/validate-cask.sh`
6. Test: `brew install --cask cask/flipio.rb`

## Validation

The formula has been validated with:

```bash
brew style --fix cask/flipio.rb     # ✓ Passed
brew audit --cask cask/flipio.rb    # Check before release
```

## Distribution

This formula can be:
- Distributed via a custom tap (homebrew-flipio)
- Submitted to the official Homebrew Cask repository

See the main documentation for details on both options.
