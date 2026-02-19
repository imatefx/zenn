class Zenn < Formula
  desc "Native macOS tiling window manager with Lua configuration"
  homepage "https://github.com/your-org/zenn"
  url "https://github.com/your-org/zenn/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "TODO"
  license "GPL-3.0-only"

  depends_on :macos => :sonoma
  depends_on "lua@5.4"
  depends_on xcode: ["15.0", :build]

  def install
    system "swift", "build",
           "-c", "release",
           "--disable-sandbox",
           "-Xlinker", "-L#{Formula["lua@5.4"].opt_lib}",
           "-Xcc", "-I#{Formula["lua@5.4"].opt_include}/lua5.4"

    bin.install ".build/release/zenn"
    bin.install ".build/release/zenn-app"
  end

  def caveats
    <<~EOS
      To start Zenn, run:
        zenn-app

      Zenn requires Accessibility permission. You will be prompted on first launch.
      Grant access in System Settings > Privacy & Security > Accessibility.

      Configuration file: ~/.config/zenn/init.lua
      A default config is created on first launch.
    EOS
  end

  service do
    run [opt_bin/"zenn-app"]
    keep_alive true
    log_path var/"log/zenn.log"
    error_log_path var/"log/zenn-error.log"
  end

  test do
    assert_match "Zenn", shell_output("#{bin}/zenn --version")
  end
end
