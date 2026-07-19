# Changelog

## 1.1.0

- Replaced the original green NUI with a complete ink-and-brass visual identity across the lobby, HUD, promotion picker, and result banner.
- Added locally bundled display typography, refined responsive behavior, accessible focus states, reduced-motion support, and restrained state transitions.
- Preserved the existing NUI actions, callback payloads, match flow, and transparent FiveM document behavior.
- Added a release thumbnail and in-game screenshot under `docs/images/`.
- Reworked the README and documentation for public release.

## 1.0.3

- Released `peak-chess` as a standalone-first FiveM resource with no mandatory framework, target, SQL, or `peak-bridge` dependency.
- Added optional `peak-bridge`, ESX, QBCore, and Qbox wrappers for identity, notifications, and money.
- Added stricter server validation for table IDs, seat colors, AI levels, move payloads, promotion pieces, and wager values.
- Added React + Vite NUI source in `web/`.
- Added lobby, PvP setup, AI setup, spectator action, ready/wager state, active HUD, promotion modal, and result banner UI.
- Removed reliance on CSS backdrop filters and blur utilities.
- Added full documentation, AI setup prompt, version metadata, and community files.
