# typed: strict
# frozen_string_literal: true

cask "flipio" do
  version "1.0.0"
  sha256 "sha256:4ec4e8bbf1c92e9f845ce41439d4387c576a6c94529d40e54f304840dd6d1a2c"

  url "https://github.com/pavel-golub/flipio/releases/download/v#{version}/Flipio-#{version}.zip"
  name "Flipio"
  desc "Instantly convert text between keyboard layouts"
  homepage "https://github.com/pavel-golub/flipio"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :big_sur"

  app "Flipio.app"

  zap trash: [
    "~/Library/Application Support/Flipio",
    "~/Library/Caches/Flipio.Flipio",
    "~/Library/HTTPStorages/Flipio.Flipio",
    "~/Library/Preferences/Flipio.Flipio.plist",
    "~/Library/Saved Application State/Flipio.Flipio.savedState",
  ]
end
