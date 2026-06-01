cask "systembar" do
  version "0.1.0"
  sha256 "35843e04dd648c0156fcbf6f0eac411fa0afa559ee41835839b5f9bc37e1e358"

  url "https://github.com/h3nryprod01/systembar/releases/download/v#{version}/SystemBar.zip"
  name "SystemBar"
  desc "Tidy, transparent menu-bar manager — collapse, reveal, and see every icon"
  homepage "https://github.com/h3nryprod01/systembar"

  depends_on macos: ">= :sonoma"

  app "SystemBar.app"

  zap trash: [
    "~/Library/Preferences/com.systembar.app.plist",
    "~/Library/Caches/SystemBar-startup.log",
  ]
end
