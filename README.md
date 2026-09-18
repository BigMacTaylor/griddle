# Griddle
Displays a fullscreen grid of all your installed applications.

![griddle](https://github.com/BigMacTaylor/griddle/blob/main/screenshots/griddle.png "Griddle")

## Installation

### Debian/Ubuntu

Download the `.deb` file from the [releases page](https://github.com/BigMacTaylor/griddle/releases) and

```bash
sudo apt install ./griddle_*.deb
```

### Fedora

Download the `.rpm` file from the [releases page](https://github.com/BigMacTaylor/griddle/releases) and

```bash
sudo dnf install ./griddle*.rpm
```

## Dependencies

- gtk3
- gtk-layer-shell

Optional (recommended):
- update-alternatives (to set default terminal)
- foot (terminal)

### Important!
Launching terminal apps, like `ranger` or `btop`, require having either the default terminal, or the `$TERMINAL` environment variable set.


## Running

Simply run the `griddle` command, or add a key binding to your sway config like:

```text
bindsym --release Super_L exec griddle
```

You can also use it in daemon mode to keep it in memory, and speed up launching.

```text
exec_always griddle --daemon-mode
```

## Customization

Config file and css are located in `~/.config/griddle/` . Griddle must be restarted for changes to take effect.

## Credits

This project was greatly inspired by nwg-drawer. You can support the original project here:
- https://github.com/nwg-piotr/nwg-drawer
