class CodexStatusBar < Formula
  desc "Menu bar app that shows local Codex activity"
  homepage "https://github.com/yuriipalam/codex-status-bar"
  url "https://github.com/yuriipalam/codex-status-bar/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "36acc80fff2d933c18c6f9e9c42c24e59feb88d8ac93c8b96d314607002c3afc"
  license "MIT"
  head "https://github.com/yuriipalam/codex-status-bar.git", branch: "main"

  depends_on macos: :ventura

  def install
    ENV["SWIFT_BUILD_FLAGS"] = "--disable-sandbox"
    system "./build.sh", "--release"
    prefix.install "build/CodexStatusBar.app"

    (bin/"codex-status-bar").write <<~EOS
      #!/bin/bash
      exec open "#{opt_prefix}/CodexStatusBar.app"
    EOS
    chmod 0755, bin/"codex-status-bar"
  end

  test do
    assert_path_exists prefix/"CodexStatusBar.app/Contents/MacOS/CodexStatusBar"
    system "codesign", "--verify", "--deep", "--strict", "--verbose=2", prefix/"CodexStatusBar.app"
  end
end
