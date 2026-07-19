# AI Configuration & Setup Prompt

Copy and paste the prompt below into your AI coding assistant to configure `peak-chess` for your server.

---

## Senior Engineer Prompt for `peak-chess` Integration

**Context:**
You are a Senior FiveM Developer. I installed the `peak-chess` resource, a standalone chess table system with PvP matches, AI matches, spectator support, optional wagers, optional target integrations, and optional `peak-bridge` support. I need it configured for my server without adding unnecessary hard dependencies.

**Objective:**
Analyze my server resources, identify optional integrations, configure the script, and validate the full gameplay flow.

**Step 1: Discovery Phase**
- Scan my server resource folder and determine whether `peak-bridge` is installed and started.
- Identify whether ESX, QBCore, or Qbox is active.
- Identify the interaction system in use: drawtext, `ox_target`, `qb-target`, `var-interact`, or another custom option.
- Confirm that the `bzzz_chess` prop pack is installed and started before `peak-chess`.
- Identify the server's preferred money account name if wagers are enabled.

**Step 2: Configuration Mapping**
- Open `shared/sh.lua`.
- Keep `Shared.Framework.autoDetect = true` unless I explicitly request manual framework selection.
- Keep `Config.Target.system = 'drawtext'` unless a supported target resource is present and I want it used.
- Update `Config.Locations` to the chess table locations I want on my map.
- Review `Config.Betting`; keep zero-wager play available, and only enable non-zero wagers when a money provider exists.
- Review `Config.AI` levels and move delays for server performance.

**Step 3: Optional Bridge And Framework Integration**
- If `peak-bridge` is present, confirm it starts before `peak-chess` and exposes identity, money, and notification helpers.
- If ESX, QBCore, or Qbox is present without `peak-bridge`, confirm the fallback wrapper can read player identity and cash.
- If no framework exists, leave the resource in standalone mode and keep wagers at `0`.

**Step 4: UI Validation**
- From `web`, run `npm install` and `npm run build`.
- Confirm `web/build/index.html` exists and the manifest still points to it.
- Search the UI source and build output to confirm there is no `backdrop-filter`, `backdrop-blur`, or blur overlay CSS.

**Step 5: Runtime Validation**
- Start the server with `peak-bridge` absent and confirm standalone chess works.
- Start the server with `peak-bridge` present and confirm bridge-backed notifications, identity, and wagers work.
- Test PvP seating, ready state, legal moves, illegal moves, check, checkmate, stalemate, promotion, resignation, spectator mode, leaving a table, and resource restart cleanup.

**Instructions for the AI:**
- Do not add a hard framework, target, SQL, or `peak-bridge` dependency.
- Do not remove standalone zero-wager play.
- Do not edit generated build files manually; change `web/src` and run `npm run build`.
- Keep custom server-specific setup in configuration where possible.
