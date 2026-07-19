# Peak Chess Documentation

The hosted documentation is available at [peakrp.net/docs/peak-chess](https://peakrp.net/docs/peak-chess).

## Overview

`peak-chess` provides playable chess tables for FiveM. It supports PvP, AI matches, spectators, optional wagers, and a React/Vite NUI. The runtime is standalone by default and does not require a framework, target system, database, or `peak-bridge`.

The full 3D chess table experience requires the `bzzz_chess` prop pack.

## Screenshots And Publication Assets

Release-ready images live in `docs/images/`:

- `peak-chess-thumbnail.png`: primary GitHub and Cfx.re forum thumbnail
- `peak-chess-gameplay.png`: in-game board and active HUD screenshot

The repository README references both files. Keep the filenames stable so GitHub image links continue to work.

## Resource Layout

```text
client/             Client gameplay, rendering, NUI, exports, framework wrappers
server/             Match lifecycle, validation, AI, betting, exports
shared/             Config, locale, chess engine
web/src/            React + Vite NUI source
web/build/          Compiled NUI loaded by fxmanifest.lua
docs/               Long-form documentation
```

## Required Asset

Install and ensure the `bzzz_chess` prop pack before `peak-chess`. The config expects table, board, chair, piece, and animation assets from that pack.

## Optional Integrations

### Framework And Bridge

`Shared.Framework.autoDetect = true` checks resources in this order:

1. `peak-bridge`
2. `es_extended`
3. `qb-core`
4. `qbx_core`
5. Standalone

`peak-bridge` is optional. When it is started and ready, `peak-chess` uses it for framework detection, identity, money, and notifications. If it is absent, the resource falls back to local ESX/QBCore/Qbox wrappers or standalone behavior.

### Target System

`Config.Target.system` supports:

- `drawtext`: default, no dependency
- `auto`: detect a supported optional target
- `ox_target`
- `qb-target`
- `var-interact`

Use `drawtext` for the most portable setup.

### Betting

Standalone play works with wagers set to `0`. Non-zero wagers require a money provider through `peak-bridge`, ESX, QBCore, or Qbox.

The server sanitizes wagers and refuses economy movement without a money provider.

## Core Config

### Tables

```lua
Config.Locations = {
    { coords = vec3(-1319.881348, -925.411011, 10.19995), heading = 104.881889, blip = true },
}
```

Each entry creates one table. Table IDs are the array indexes.

### AI

```lua
Config.AI = {
    enabled = true,
    levels = {
        { id = 'easy', depth = 2, randomness = 0.35, moveDelay = { 1800, 3500 } },
        { id = 'medium', depth = 3, randomness = 0.12, moveDelay = { 2200, 4500 } },
        { id = 'hard', depth = 4, randomness = 0.0, moveDelay = { 2800, 6000 } },
    },
    maxThinkMs = 1500,
}
```

Only configured AI level IDs are accepted by the server.

## Server Events

These are internal gameplay events. Payloads are validated server-side.

```lua
TriggerServerEvent('peak-chess:sit', tableId, 'white' or 'black')
TriggerServerEvent('peak-chess:spectate', tableId)
TriggerServerEvent('peak-chess:requestState', tableId)
TriggerServerEvent('peak-chess:leave', tableId)
TriggerServerEvent('peak-chess:startAI', tableId, 'white' or 'black', 'easy' or 'medium' or 'hard', bet)
TriggerServerEvent('peak-chess:setReady', tableId, ready, bet)
TriggerServerEvent('peak-chess:move', tableId, fromSquare, toSquare, promotionPiece)
TriggerServerEvent('peak-chess:resign', tableId)
```

Valid squares use chess notation from `a1` through `h8`. Valid promotion pieces are `q`, `r`, `b`, and `n`.

## Client Events

```lua
RegisterNetEvent('peak-chess:self', function(data) end)
RegisterNetEvent('peak-chess:sync', function(snapshot) end)
RegisterNetEvent('peak-chess:gameover', function(data) end)
RegisterNetEvent('peak-chess:lobbyState', function(snapshot) end)
RegisterNetEvent('peak-chess:notify', function(message, kind) end)
```

## Server Exports

### GetMatch

```lua
local match = exports['peak-chess']:GetMatch(1)
```

Returns a sanitized match object or `nil`.

### GetPlayerMatch

```lua
local data = exports['peak-chess']:GetPlayerMatch(source)
```

Returns `{ tableId, color, status }` when the player is seated, otherwise `nil`.

### IsPlayerInGame

```lua
local inGame = exports['peak-chess']:IsPlayerInGame(source)
```

Returns `true` when the player is seated in a playing match.

### GetActiveMatches

```lua
local active = exports['peak-chess']:GetActiveMatches()
```

Returns an array of active playing matches.

### StartAIGame

```lua
local ok = exports['peak-chess']:StartAIGame(source, 1, 'white', 'medium', 0)
```

Starts an AI game when the table, side, level, and wager are valid.

### ForceEndMatch

```lua
local ok = exports['peak-chess']:ForceEndMatch(1, 'white')
```

Force-ends a playing match. `winnerColor` may be `white`, `black`, or `nil` for no winner.

## Client Exports

### IsSeated

```lua
local seated = exports['peak-chess']:IsSeated()
```

### IsInGame

```lua
local playing = exports['peak-chess']:IsInGame()
```

### GetCurrentTable

```lua
local tableId = exports['peak-chess']:GetCurrentTable()
```

### GetColor

```lua
local color = exports['peak-chess']:GetColor()
```

Returns `white`, `black`, or `nil`.

### OpenLobby

```lua
local opened = exports['peak-chess']:OpenLobby(1)
```

Opens the NUI lobby for a valid table.

## NUI Messages

The client sends these messages into the React app:

- `lobby`: show or update the lobby
- `hud`: show or update the active HUD
- `promotion`: show or hide promotion selection
- `gameover`: show the result banner
- `closeAll`: close all UI states

## NUI Callbacks

The React app posts these callbacks back to FiveM:

- `sit`
- `spectate`
- `startAI`
- `setReady`
- `resign`
- `promote`
- `leave`
- `closeLobby`

## UI Development

Install dependencies and build:

```powershell
cd web
npm install
npm run build
```

Debug views are available in a browser preview:

```text
?debug=lobby
?debug=hud
?debug=promotion
?debug=result
?debug=all
```

Debug pages also support state shortcuts without navigation: `1` lobby, `2` HUD, `3` promotion, `4` result, and `5` combined.

The UI uses plain CSS tokens and components. It intentionally avoids Tailwind output, `backdrop-filter`, `backdrop-blur`, and blur overlay utilities.

### Visual System

The interface uses a transparent FiveM document with an ink-and-brass visual system:

- `BBH Sans Bartle` is the display face for the product name, result state, and pot value.
- `Poppins` is the utility face for controls and match information.
- Warm brass is the single primary action and selection color.
- Lobby, HUD, promotion, and result states share the same surface, border, spacing, and motion tokens.
- Motion is limited to panel entry, state entry, hover feedback, and the active-turn pulse.
- `prefers-reduced-motion` collapses animation and transition durations for accessibility.

Do not add an opaque background to `html`, `body`, or `#root`; hidden NUI transparency is required to prevent the interface from covering gameplay.

## Validation Checklist

- Start without `peak-bridge`; play a zero-wager PvP game.
- Start with `peak-bridge`; confirm money, identity, and notifications.
- Start an AI game.
- Complete a PvP ready flow.
- Attempt legal and illegal moves.
- Promote a pawn.
- Resign.
- Reach checkmate and stalemate.
- Open spectator HUD.
- Restart the resource during and after a match.
- Run the UI build and audit for forbidden backdrop CSS.

## Troubleshooting

### Props Do Not Spawn

Confirm the `bzzz_chess` prop pack is installed, started before `peak-chess`, and uses the model names configured in `Config.Models`.

### Wagers Do Not Appear

Wagers are hidden when no money provider is available. Start `peak-bridge`, ESX, QBCore, or Qbox before `peak-chess`, or keep wagers at `0`.

### Target Interaction Does Not Appear

Use `Config.Target.system = 'drawtext'` first. Once drawtext works, switch to an optional target system if desired.

### UI Does Not Load

Run `npm run build` from `web` and confirm `web/build/index.html` exists. The manifest must continue to load `web/build/index.html`.
