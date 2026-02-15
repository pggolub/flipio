# Homebrew Cask Release Guide

This guide explains how to release Flipio via Homebrew Cask with manual builds.

## Prerequisites

- Xcode installed and configured
- Homebrew installed locally (for validation)
- GitHub repository with releases enabled
- Access to push to the repository

## Release Process

### Step 1: Build the Release

1. Open the project in Xcode
2. Select **Product > Archive**
3. In the Organizer, select your archive and click **Distribute App**
4. Choose distribution method:
   - For unsigned: **Copy App**
   - For signed: **Developer ID** (requires Apple Developer account)
5. Save the exported `Flipio.app`

### Step 2: Create ZIP Archive

The Homebrew Cask installer expects a ZIP file containing `Flipio.app`:

```bash
# Navigate to where you exported the app
cd path/to/export

# Create a properly structured ZIP
ditto -c -k --keepParent "Flipio.app" "Flipio-1.0.0.zip"
```

**Important**: Replace `1.0.0` with your actual version number.

### Step 3: Calculate SHA256

Use the helper script to calculate the checksum:

```bash
./scripts/calculate-sha256.sh Flipio-1.0.0.zip
```

This will output something like:
```
SHA256: abc123def456...
```

Save this hash - you'll need it for the next step.

### Step 4: Create GitHub Release

1. Go to https://github.com/pavel-golub/flipio/releases/new
2. Fill in the details:
   - **Tag**: `v1.0.0` (must match version in cask)
   - **Release title**: `Flipio v1.0.0`
   - **Description**: Add your changelog/release notes
3. Upload `Flipio-1.0.0.zip`
4. Click **Publish release**

### Step 5: Update Cask Formula

Edit `cask/flipio.rb`:

```ruby
cask "flipio" do
  version "1.0.0"  # ← Update this
  sha256 "abc123def456..."  # ← Update with SHA256 from Step 3

  url "https://github.com/pavel-golub/flipio/releases/download/v#{version}/Flipio-#{version}.zip"
  # ... rest stays the same
```

### Step 6: Validate the Cask

Run the validation script:

```bash
./scripts/validate-cask.sh
```

This will:
- Run `brew style` to check formatting
- Run `brew audit` to validate the cask

Fix any issues before proceeding.

### Step 7: Test Installation Locally

Test the cask on your machine:

```bash
# Install from local cask file
HOMEBREW_NO_INSTALL_FROM_API=1 brew install --cask cask/flipio.rb

# Test the app
open /Applications/Flipio.app

# Uninstall
brew uninstall --cask flipio
```

### Step 8: Distribute the Cask

#### Option A: Create Your Own Tap (Recommended)

1. Create a new GitHub repository named `homebrew-flipio` or `homebrew-cask`

2. Structure it like this:
   ```
   homebrew-flipio/
   ├── Casks/
   │   └── flipio.rb
   └── README.md
   ```

3. Copy your cask:
   ```bash
   mkdir -p Casks
   cp cask/flipio.rb Casks/flipio.rb
   git add Casks/flipio.rb
   git commit -m "Add Flipio cask v1.0.0"
   git push
   ```

4. Users can now install with:
   ```bash
   brew tap pavel-golub/flipio
   brew install --cask flipio
   ```

#### Option B: Submit to Official Homebrew Cask

For wider distribution, submit to the official repository:

1. Fork https://github.com/Homebrew/homebrew-cask

2. Add your cask to `Casks/f/flipio.rb` (note the `f/` subdirectory)

3. Test thoroughly:
   ```bash
   brew style --fix Casks/f/flipio.rb
   brew audit --cask --new --online Casks/f/flipio.rb
   brew install --cask --build-from-source flipio
   brew uninstall --cask flipio
   ```

4. Create a pull request following Homebrew's guidelines

5. Respond to maintainer feedback

## Updating for New Releases

When releasing a new version:

1. Build and export the new version
2. Create ZIP with new version number: `Flipio-1.1.0.zip`
3. Calculate new SHA256
4. Create new GitHub release with new tag (`v1.1.0`)
5. Update `cask/flipio.rb`:
   - Change `version "1.1.0"`
   - Change `sha256 "new_hash"`
6. Validate and test
7. Update your tap repository or submit new PR to Homebrew

## Troubleshooting

### "App can't be opened because Apple cannot check it"

If you're not code signing:
- Users need to right-click → Open the first time
- Or run: `xattr -cr /Applications/Flipio.app`

For production releases, consider getting an Apple Developer certificate and code signing + notarizing your app.

### SHA256 Mismatch on Install

- Make sure you calculated SHA256 of the exact file uploaded to GitHub
- Use `shasum -a 256 filename.zip` (not `sha256sum`)
- Don't modify the ZIP after calculating the hash

### Cask Audit Fails

Common issues:
- URL returns 404: Ensure GitHub release is published (not draft)
- Invalid `desc`: Keep it short and factual (no marketing language)
- Missing `livecheck`: Already included in the template

### App Not Found in ZIP

The ZIP must contain `Flipio.app` at the root level:
```
Flipio-1.0.0.zip
└── Flipio.app/
```

Not in a subdirectory:
```
Flipio-1.0.0.zip
└── Release/
    └── Flipio.app/  ← Wrong
```

Use `ditto -c -k --keepParent` as shown in Step 2 to create proper structure.

## Quick Reference Checklist

- [ ] Build release in Xcode
- [ ] Export app bundle
- [ ] Create ZIP: `ditto -c -k --keepParent Flipio.app Flipio-X.Y.Z.zip`
- [ ] Calculate SHA256: `./scripts/calculate-sha256.sh`
- [ ] Create GitHub release with tag `vX.Y.Z`
- [ ] Upload ZIP to GitHub release
- [ ] Update `cask/flipio.rb` with version and sha256
- [ ] Validate: `./scripts/validate-cask.sh`
- [ ] Test locally: `brew install --cask cask/flipio.rb`
- [ ] Update tap repository or submit PR

## Resources

- [Homebrew Cask Documentation](https://docs.brew.sh/Cask-Cookbook)
- [Acceptable Casks](https://docs.brew.sh/Acceptable-Casks)
- [GitHub Releases Guide](https://docs.github.com/en/repositories/releasing-projects-on-github)
