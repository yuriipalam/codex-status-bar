class CodexStatusBar < Formula
  desc "Menu bar app that shows local Codex activity"
  homepage "https://github.com/yuriipalam/codex-status-bar"
  url "https://github.com/yuriipalam/codex-status-bar.git", branch: "main"
  version "0.2.0"
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
