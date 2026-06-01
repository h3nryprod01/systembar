cask "systembar" do
  version "0.1.0"
  sha256 :no_check # replace with the release zip's sha256 once published

  url "https://github.com/nguyenphucuong/systembar/releases/download/v#{version}/SystemBar.zip"
  name "SystemBar"
  desc "Tidy, transparent menu-bar manager — collapse, reveal, and see every icon"
  homepage "https://github.com/nguyenphucuong/systembar"

  depends_on macos: ">= :sonoma"

  app "SystemBar.app"

  zap trash: [
    "~/Library/Preferences/com.systembar.app.plist",
    "~/Library/Caches/SystemBar-startup.log",
  ]
end
