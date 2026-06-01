cask "systembar" do
  version "0.2.0"
  sha256 "eb068b0c8d172cbe190bc4d34ba3b4ae15d8708386e79423e10324f447e65259"

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
