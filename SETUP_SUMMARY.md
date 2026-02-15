# Homebrew Cask Setup Complete ✅

Your Flipio project is now configured for Homebrew Cask distribution!

## What Was Created

### 📦 Cask Formula
- **[cask/flipio.rb](cask/flipio.rb)** - Homebrew Cask formula (✓ style validated)
- **[cask/README.md](cask/README.md)** - Cask documentation

### 🔧 Helper Scripts
- **[scripts/calculate-sha256.sh](scripts/calculate-sha256.sh)** - Calculate ZIP checksums
- **[scripts/validate-cask.sh](scripts/validate-cask.sh)** - Validate cask formula
- **[scripts/README.md](scripts/README.md)** - Scripts documentation

### 📚 Documentation
- **[HOMEBREW_RELEASE.md](HOMEBREW_RELEASE.md)** - Complete release guide (detailed)
- **[QUICK_RELEASE.md](QUICK_RELEASE.md)** - Quick reference checklist
- **[README.md](README.md)** - Updated with Homebrew installation instructions

## Quick Start Guide

### For Your Next Release

1. **Build in Xcode**
   - Product → Archive
   - Distribute App → Export

2. **Create ZIP**
   ```bash
   ditto -c -k --keepParent "Flipio.app" "Flipio-1.0.0.zip"
   ```

3. **Calculate SHA256**
   ```bash
   ./scripts/calculate-sha256.sh Flipio-1.0.0.zip
   ```

4. **Create GitHub Release**
   - Tag: `v1.0.0`
   - Upload: `Flipio-1.0.0.zip`

5. **Update Cask**
   
   Edit [cask/flipio.rb](cask/flipio.rb):
   ```ruby
   version "1.0.0"           # Update this
   sha256 "abc123..."        # Paste from step 3
   ```

6. **Validate**
   ```bash
   ./scripts/validate-cask.sh
   ```

7. **Test Locally**
   ```bash
   HOMEBREW_NO_INSTALL_FROM_API=1 brew install --cask cask/flipio.rb
   ```

8. **Distribute**
   
   Create a tap repository (`homebrew-flipio`) and copy the cask there.

## Users Can Install With

```bash
brew tap pavel-golub/flipio
brew install --cask flipio
```

## Validation Status

✅ Cask formula style check: **PASSED**
```
brew style --fix cask/flipio.rb
1 file inspected, no offenses detected
```

⏳ Full audit: Run after publishing to tap
```
brew audit --cask --online flipio
```

## What's Next

1. **Before first release**: Update `version` and `sha256` in cask/flipio.rb after building
2. **Create a tap**: Make a `homebrew-flipio` repository on GitHub
3. **Test locally**: Install from your local cask file
4. **Optional**: Submit to official Homebrew Cask for wider distribution

## Reference

- **Quick Checklist**: See [QUICK_RELEASE.md](QUICK_RELEASE.md)
- **Detailed Guide**: See [HOMEBREW_RELEASE.md](HOMEBREW_RELEASE.md)
- **Scripts Help**: See [scripts/README.md](scripts/README.md)

---

**All files are ready!** Build your app and follow the Quick Start Guide above. 🚀
