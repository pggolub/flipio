# Helper Scripts for Homebrew Cask Release

This directory contains helper scripts for releasing Flipio via Homebrew Cask.

## Scripts

### calculate-sha256.sh

Calculates the SHA256 checksum of your release ZIP file.

**Usage:**
```bash
./scripts/calculate-sha256.sh path/to/Flipio-1.0.0.zip
```

**Output:**
```
SHA256: abc123def456...

Update the cask formula:
  sha256 "abc123def456..."
```

Copy the hash and paste it into `cask/flipio.rb`.

---

### validate-cask.sh

Validates the Homebrew Cask formula using official Homebrew tools.

**Usage:**
```bash
./scripts/validate-cask.sh
```

**What it does:**
- Runs `brew style --fix` to check and fix formatting
- Runs `brew audit --cask --online` to validate the formula

**Exit codes:**
- `0` - All checks passed
- `1` - Validation failed (check output for details)

**Requirements:**
- Homebrew must be installed
- The cask file must exist at `cask/flipio.rb`

---

## Workflow Example

After building your app and creating a GitHub release:

```bash
# 1. Calculate SHA256 of your ZIP
./scripts/calculate-sha256.sh ~/Desktop/Flipio-1.0.0.zip

# 2. Update cask/flipio.rb with the version and SHA256

# 3. Validate the cask
./scripts/validate-cask.sh

# 4. If validation passes, you're ready to distribute!
```

## Permissions

All scripts have executable permissions. If needed, restore with:

```bash
chmod +x scripts/*.sh
```

## Related Documentation

- [HOMEBREW_RELEASE.md](../HOMEBREW_RELEASE.md) - Complete release guide
- [QUICK_RELEASE.md](../QUICK_RELEASE.md) - Quick reference checklist
- [cask/README.md](../cask/README.md) - Cask formula documentation
