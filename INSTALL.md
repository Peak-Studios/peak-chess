# Peak Chess Installation

This guide installs `peak-chess` as a standalone FiveM resource. Framework, target, and bridge integrations are optional.

The latest hosted documentation is also available at [peakrp.net/docs/peak-chess](https://peakrp.net/docs/peak-chess).

## 1. Install Files

Place the resource at:

```text
resources/[peak]/peak-chess
```

The folder name should remain `peak-chess` unless you also update every resource reference and NUI callback expectation.

## 2. Install Assets

Install the `bzzz_chess` prop pack and ensure it before `peak-chess`. The full 3D table experience expects these models and animations:

- `bzzz_chess_table_a`
- `bzzz_chess_board_a`
- `bzzz_chess_chair_a`
- `bzzz_chess_color_a1` through `bzzz_chess_color_a6`
- `bzzz_chess_color_b1` through `bzzz_chess_color_b6`
- `bzzz_chess_animations`

## 3. Add Server Ensures

Standalone server:

```cfg
ensure your_bzzz_chess_prop_pack
ensure peak-chess
```

Server using `peak-bridge`:

```cfg
ensure peak-bridge
ensure your_bzzz_chess_prop_pack
ensure peak-chess
```

Optional target resources such as `ox_target`, `qb-target`, and `var-interact` should start before `peak-chess` when used.

## 4. Configure Framework Mode

Open [shared/sh.lua](shared/sh.lua).

By default, `Shared.Framework.autoDetect = true`:

1. Uses `peak-bridge` when the resource is started.
2. Falls back to ESX when `es_extended` is started.
3. Falls back to QBCore when `qb-core` is started.
4. Falls back to Qbox when `qbx_core` is started.
5. Uses standalone mode otherwise.

Manual framework selection is also supported:

```lua
Shared.Framework = {
    autoDetect = false,
    PeakBridge = false,
    ESX        = false,
    QBCore     = false,
    Qbox       = false,
    Standalone = true,
}
```

## 5. Configure Tables

Edit `Config.Locations` in [shared/sh.lua](shared/sh.lua):

```lua
Config.Locations = {
    { coords = vec3(-1319.881348, -925.411011, 10.19995), heading = 104.881889, blip = true },
}
```

Each entry becomes a chess table. Table IDs are the array index, starting at `1`.

## 6. Configure Interaction

`drawtext` is the default and has no dependency:

```lua
Config.Target.system = 'drawtext'
```

Optional values:

- `auto`
- `ox_target`
- `qb-target`
- `var-interact`

If the configured target resource is missing, use `drawtext` or `auto`.

## 7. Configure Wagers

Wagers are optional. Standalone mode always supports playable no-wager chess.

```lua
Config.Betting = {
    enabled  = true,
    account  = 'cash',
    min      = 0,
    max      = 50000,
    presets  = { 0, 100, 500, 1000, 5000 },
    houseCut = 0.0,
    drawRefund = true,
}
```

Non-zero wagers require a money provider through `peak-bridge`, ESX, QBCore, or Qbox. Without a provider, the UI hides wager controls and the server sanitizes wager values to `0`.

## 8. Configure AI

AI play is enabled by default:

```lua
Config.AI.enabled = true
```

Each AI level has a search depth, randomness value, and move delay. Keep `Config.AI.maxThinkMs` conservative on busy servers.

## 9. Build The UI

The repository includes `web/build`, but run a fresh build after UI changes:

```powershell
cd web
npm install
npm run build
```

The generated bundle must remain at `web/build/index.html` because `fxmanifest.lua` points there.

## 10. Validate In Game

Check these flows after installation:

- Start with no framework and no `peak-bridge`; confirm a zero-wager PvP game can be played.
- Start with `peak-bridge`; confirm identity, notifications, and optional money integration work.
- Start an AI game from the lobby.
- Run a PvP ready flow from both seats.
- Attempt an illegal move and confirm it is rejected.
- Promote a pawn and confirm the promotion modal appears.
- Test resignation, checkmate, stalemate, spectator mode, and resource restart cleanup.
