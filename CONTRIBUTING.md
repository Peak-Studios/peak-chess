# Contributing

Thanks for improving `peak-chess`.

## Development Setup

1. Install the resource in a local FiveM test server.
2. Install the `bzzz_chess` prop pack.
3. Install UI dependencies when changing the NUI:

```powershell
cd web
npm install
npm run build
```

## Guidelines

- Keep standalone mode working.
- Do not introduce mandatory framework, target, database, or `peak-bridge` dependencies.
- Keep all economy changes server-side.
- Keep UI changes in `web/src` and run `npm run build` so `web/build` stays current.
- Do not add CSS `backdrop-filter`, `backdrop-blur`, or blur overlay dependencies.
- Preserve existing exports and events unless a breaking change is explicitly approved.
- Keep pull requests focused and include testing notes.

## Test Checklist

- Standalone no-wager PvP
- Optional `peak-bridge` money and notification flow
- AI game start
- PvP ready flow
- Legal and illegal moves
- Promotion
- Resignation
- Checkmate and stalemate
- Spectator HUD
- Resource restart cleanup
