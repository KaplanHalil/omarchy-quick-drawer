# Quick Drawer

A centered quick-toggle drawer for the [Omarchy](https://omarchy.org) bar.

![Quick Drawer](preview.png)

![Add tiles](preview-settings.png)

Quick Drawer puts the things you reach for all day — caffeine, night light,
do-not-disturb, screensaver and suspend — behind one bar mark. Add panel
shortcuts and your own command tiles from the built-in catalogue.

> This is a clone of Omarchy's `omarchy.indicators` widget. The clone keeps
> the source-specific first-party service access, so the service-backed
> toggles work without shelling out and polling.

## Features

- One sliders mark in the bar's center section.
- A card that opens horizontally centered under the bar.
- Service-backed **Caffeine**, **Night Light** and **DND** toggles.
- **Screensaver**, **Suspend** and **Touchpad** flag toggles.
- Panel shortcuts for **Audio**, **Network**, **Power** and **Monitor**.
- **Reminders** opens the reminder flow.
- **Add tiles** view with a catalogue and switches.
- **Custom command tiles**: label, Nerd Font glyph and a `bash -lc` command.
- Selections persist in `shell.json` and survive shell restarts.
- Touchpad disappears when the machine has no touchpad.
- A small accent dot means one of Caffeine, Night Light or DND is on.

## Requirements

- Omarchy 4.x with the Quickshell shell.
- A Nerd Font set as the bar's font (the mark and tile glyphs need it).

## Install

```bash
omarchy plugin add https://github.com/KaplanHalil/omarchy-quick-drawer.git --enable
```

The widget replaces the stock `omarchy.indicators` entry in the center
section. If you later want to move it:

```bash
omarchy bar move io.github.kaplanhalil.quickdrawer --section center
```

## Use

- Left-click the sliders mark to open the drawer.
- Click outside to close it.
- Click the gear in the drawer header to open **Add tiles**.
- Use the switches to add or remove tiles.
- **Add custom command** creates a tile with your own label, glyph and
  command. The command runs with `bash -lc` as your user.

### Default tiles

| Tile | What it does |
| --- | --- |
| Caffeine | Stay awake (`omarchy.idle` `stayAwake`) |
| Night Light | Blue-light filter (`omarchy.nightlight`) |
| DND | Notification silencing (`omarchy.notifications`) |
| Screensaver | Enables/disables the screensaver (`screensaver-off` flag) |
| Suspend | Enables/disables suspend (`suspend-off` flag) |

### Catalogue

Audio, Network, Power, Monitor, Reminders, Touchpad, and the five default
tiles. Panel tiles close the drawer and open the matching Omarchy panel.

## IPC

The IPC target stays `omarchy.indicators` so the clone routing keeps working.

```bash
omarchy-shell omarchy.indicators open
omarchy-shell omarchy.indicators close
omarchy-shell omarchy.indicators toggle
omarchy-shell omarchy.indicators openSettings
omarchy-shell omarchy.indicators openGrid
omarchy-shell omarchy.indicators toggleCaffeine
omarchy-shell omarchy.indicators toggleNightLight
omarchy-shell omarchy.indicators toggleDnd
omarchy-shell omarchy.indicators toggleScreensaver
omarchy-shell omarchy.indicators toggleSuspend
omarchy-shell omarchy.indicators addTile audio
omarchy-shell omarchy.indicators removeTile audio
```

## Custom commands

Custom commands are powerful and run unsandboxed:

```bash
notify-send 'Quick Drawer' 'The custom tile ran'
```

Only add commands you trust. The drawer shows the same warning in the form.

## Remove

```bash
omarchy plugin remove io.github.kaplanhalil.quickdrawer
```

This restores the stock `omarchy.indicators` widget in the same slot.

## Support

If Quick Drawer is useful to you:

[☕ Buy me a coffee](https://www.buymeacoffee.com/kaplanhalil)

## Credits

- Derived from Omarchy's `omarchy.indicators` widget
  ([basecamp/omarchy](https://github.com/basecamp/omarchy), MIT).
- Built for the Omarchy 4.x Quickshell shell.

## License

MIT — see [LICENSE](LICENSE).
