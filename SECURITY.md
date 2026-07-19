# Security Policy

## Supported Versions

Security fixes are handled for the latest public release of `peak-chess`.

## Reporting A Vulnerability

Report security issues privately through the Peak Studios Discord or by contacting the repository maintainers. Do not open a public issue for an exploit, money duplication path, or remote event abuse report.

Please include:

- Resource version
- Server artifact version
- Framework or bridge in use
- Reproduction steps
- Relevant logs or screenshots with private data removed

## Scope

The server validates table IDs, seat colors, AI levels, move squares, promotion pieces, and wager values. If you add custom integrations, keep money and permission checks server-side.

Never trust NUI payloads or client events for economy changes.
