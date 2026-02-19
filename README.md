# Griddle
Display a fullscreen grid of all your installed applications.

It searches for apps in XDG user directories and fallsback to /usr/local/share/applications.

![griddle](https://github.com/BigMacTaylor/griddle/blob/main/screenshots/griddle.png "Griddle")

## Installation

### Debian/Ubuntu

Download the `.deb` file from the [releases page](https://github.com/BigMacTaylor/griddle/releases) and

```bash
sudo apt install ./griddle_*.deb
```

## Dependencies

- gtk3
- gtk-layer-shell

Optional (recommended):

- update-alternatives (to set default terminal)

### Important!
Launching terminal apps, like `ranger` or `btop`, require having either the default terminal, or the `$TERMINAL` environment variable set.


## Running

Simply run the `griddle` command, or add a key binding to your sway config like:

```text
bindsym Mod4+s exec griddle
```

*NOTE: The first time you run the `griddle` command it will parse the config file, data directories, and .desktop files. Subsequent commands simply show / hide the window, and will continue running in the background.*

## Customization

Config file and css are located in `~/.config/griddle/` . Griddle must be restarted in order for changes to take effect.

## Credits

This project was greatly inspired by nwg-drawer. You can support the original project here:
- https://github.com/nwg-piotr/nwg-drawer
