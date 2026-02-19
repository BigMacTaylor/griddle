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
foreignDep "libgtk-3-0"
foreignDep "libgtk-layer-shell0"
