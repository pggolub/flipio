# Quick Release Checklist

Use this as a quick reference when creating a new release.

## Prerequisites

- [ ] Xcode project version updated
- [ ] Changelog/release notes prepared
- [ ] All changes committed to git

## Release Steps

### 1. Build in Xcode

```
Product → Archive
Organizer → Distribute App → Copy App (or Developer ID)
```

Save `Flipio.app` to a known location.

### 2. Create ZIP

```bash
cd path/to/exported/app
ditto -c -k --keepParent "Flipio.app" "Flipio-1.0.0.zip"
```

### 3. Calculate SHA256

```bash
./scripts/calculate-sha256.sh Flipio-1.0.0.zip
```

**Save the hash!** You'll need it in step 5.

### 4. Create GitHub Release

1. Go to: https://github.com/pavel-golub/flipio/releases/new
2. Tag: `v1.0.0` (matches ZIP version)
3. Title: `Flipio v1.0.0`
4. Upload: `Flipio-1.0.0.zip`
5. Click **Publish release**

### 5. Update Cask

Edit `cask/flipio.rb`:

```ruby
version "1.0.0"           # ← Update
sha256 "abc123..."        # ← Paste from step 3
```

### 6. Validate

```bash
./scripts/validate-cask.sh
```

Fix any errors, then proceed.

### 7. Test Locally

```bash
HOMEBREW_NO_INSTALL_FROM_API=1 brew install --cask cask/flipio.rb
open /Applications/Flipio.app
brew uninstall --cask flipio
```

### 8. Update Tap

```bash
cd /path/to/homebrew-flipio
cp /path/to/Flipio/cask/flipio.rb Casks/flipio.rb
git add Casks/flipio.rb
git commit -m "Update Flipio to v1.0.0"
git push
```

## Done! 🎉

Users can now update with:
```bash
brew update
brew upgrade flipio
```

---

**Need more details?** See [HOMEBREW_RELEASE.md](HOMEBREW_RELEASE.md)
