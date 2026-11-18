# Pardona's UI

Purple-gold look for parts of the default World of Warcraft Forever interface.

Pardona's UI is part of the Pardona addon suite and also runs on its own – it does not need any other Pardona addon. It only changes the look of Blizzard frames: positions, sizes and scale stay with Edit Mode, and no frame is moved, reparented or rescripted. Tooltips are not touched.

The styling itself comes from the shared library LibPardona-1.0. **Current state:** the module framework, the settings page and a frame analysis are in place; the actual styling of each module arrives together with LibPardona 1.1.0. Until then every module shows "waiting for LibPardona 1.1.0" and changes nothing.

## Modules

Each module can be switched on and off at runtime, without `/reload` (during combat the change is applied when combat ends).

- **Minimap (square)** (beta) – square minimap with a purple-gold frame.
- **Buffs & debuffs** (beta) – purple-gold borders for buff and debuff icons.
- **Loot window** (beta) – purple-gold look for the loot window.
- **Group loot rolls** (beta) – purple-gold look for need/greed roll frames.
- **Trade window** (beta) – purple-gold look for the trade window.

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
- Pardona's UI does not require any other UI, minimap or loot replacement addon, and it does not detect them. If another addon restyles or replaces the same frames, switch the matching module off.
- A version notice is printed at login only for beta, alpha and developer versions.

## Development

- `tools\fetch-libs.ps1` copies LibPardona-1.0 into `Libs\lib-pardona` (from the sibling repository `..\lib-pardona`, otherwise from GitHub). `Libs\` is not part of the repository; the packager fetches the library via `.pkgmeta`.
- Before every commit: `luacheck .` (0 warnings / 0 errors) and `luac5.1 -p` on every own `.lua` file (WoW uses Lua 5.1: at most 200 locals and 60 upvalues per function). CI runs both.
- Branches: `main` holds releases, `develop` the next version.
