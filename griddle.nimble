# Package

version       = "1.0.3"
author        = "Mac Taylor"
description   = "A fullscreen app grid for wayland"
license       = "GPL-3.0-only"
srcDir        = "src"
bin           = @["griddle"]


# Dependencies
requires "nim >= 2.2.4"
requires "https://github.com/BigMacTaylor/nim2gtk.git"

# Foreign Dependencies
foreignDeps  = @["libgtk-3-0", "libgtk-layer-shell0"]

task release, "Build release":
    exec "nim c -d:release -d:strip --opt:size -o:bin/griddle src/griddle.nim"
