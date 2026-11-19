# Pardona's UI

Purple-gold look for parts of the default World of Warcraft Forever interface.

Pardona's UI is part of the Pardona addon suite and also runs on its own – it does not need any other Pardona addon. It only changes the look of Blizzard frames: positions, sizes and scale stay with Edit Mode, and no frame is moved, reparented or rescripted. Tooltips are not touched.

The styling itself comes from the style API of the shared library LibPardona-1.0 (LibPardona 1.1.0). **Current state:** the minimap and buff/debuff modules are styled; loot window, group loot rolls and trade window are not styled yet. If the loaded LibPardona has no style API, every module shows "waiting for LibPardona 1.1.0" and changes nothing.

## Modules

Each module can be switched on and off at runtime, without `/reload` (during combat the change is applied when combat ends).

- **Minimap (square)** (beta) – square minimap: the round ring is hidden, the map gets a square gold frame 4 px outside its edge with a purple background as a passe-partout. The zone line gets a thin frame and a gold zone name; the tracking, mail, calendar and addon compartment buttons get small button frames; the clock text uses the Pardona text font. The zoom buttons and any buttons of other addons stay unchanged. Switching the module off restores the round minimap with its ring.
- **Buffs & debuffs** (beta) – a fine square border around every buff and debuff icon (icons slightly cropped) and the Pardona text font for the remaining duration. Buffs get a gold border; debuffs keep the colour of their debuff type (e.g. poison green, curse purple) – if that colour cannot be read, they get the gold border and the default debuff border stays visible. Cancelling a buff with right-click is unchanged.
- **Loot window** (beta, styling not yet implemented)
- **Group loot rolls** (beta, styling not yet implemented)
- **Trade window** (beta, styling not yet implemented)

Modules marked (beta) are experimental: they are on by default in beta, alpha and developer versions and off by default in release versions. An explicit choice on the settings page always wins.

## Options

Settings are under **Options → AddOns → Pardona's Addons → UI**, or via `/pui`. The page lists every module with a checkbox, a short description and its status:

- *active* – the module is styling its frames
- *off* – switched off
- *frame not found* – the Blizzard frame does not exist in this client
- *waiting for LibPardona 1.1.0* – the loaded LibPardona has no style API yet
- *experimental* – the module is not yet tested in game

The "Pardona's Addons" overview, the shared minimap button and the addon compartment show a short status such as "3/5 modules active".

## Slash commands

| Command | Description |
| --- | --- |
| `/pui` | Open the settings page |
| `/pui frames [minimap\|auras\|loot\|grouploot\|trade]` | Frame analysis of the default UI (all modules or one); written to the saved variables on `/reload` |
| `/pui help` | List the commands |

The frame analysis only reads frames and stores what it finds in `WTF\Account\<ACCOUNT>\SavedVariables\PardonasUI.lua`. Running it for one module replaces only that module's section, so e.g. `/pui frames trade` can be repeated with the trade window open.

## Compatibility

- Client: WoW Forever (Interface 16001).
- The minimap module provides the global function `GetMinimapShape()` (returns `"SQUARE"` while the module is active, otherwise `"ROUND"`), so minimap buttons of LibDBIcon-1.0 and the Pardona minimap button sit on the square edge. It is only defined if no other addon has defined it before; an existing one is never replaced.
- Pardona's UI does not require any other UI, minimap or loot replacement addon, and it does not detect them. If another addon restyles or replaces the same frames, switch the matching module off.
- A version notice is printed at login only for beta, alpha and developer versions.

## Development

- `tools\fetch-libs.ps1` copies LibPardona-1.0 into `Libs\lib-pardona` (from the sibling repository `..\lib-pardona`, otherwise from GitHub). `Libs\` is not part of the repository; the packager fetches the library via `.pkgmeta`.
- Before every commit: `luacheck .` (0 warnings / 0 errors) and `luac5.1 -p` on every own `.lua` file (WoW uses Lua 5.1: at most 200 locals and 60 upvalues per function). CI runs both.
- Until LibPardona 1.1.0 is tagged, the sibling repository `..\lib-pardona` must have its `develop` branch checked out, so that `tools\fetch-libs.ps1` copies the style API (`LibPardona-1.0\Style.lua`).
- Branches: `main` holds releases, `develop` the next version.
