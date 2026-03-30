# Development

This repo ships a native Godot build of the DopaQiX web game.

## Prerequisites

- Windows
- Godot 4.6 or newer
- PowerShell

## Run From Source

1. Open the repo in Godot.
2. Run `main.tscn`.

Command-line smoke check:

```powershell
godot --headless --path . --quit-after 1
```

## Create A Player Build

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-windows.ps1
```

That script:

- ensures the correct Godot Windows export templates are installed
- exports `dist/DopaQixNative2.exe`
- creates `dist/DopaQixNative2-win64.zip`

## Key Files

- `project.godot`: project configuration
- `main.tscn`: root scene
- `scripts/game.gd`: main gameplay, rendering, pickups, scoring, level flow, and UI
- `scripts/audio_synth.gd`: procedural music and sound generation
- `scripts/export-windows.ps1`: Windows export and zip packaging
- `.agents/tasks/prd-dopaqix-native2.json`: Ralph tracking for this repo

## Source Of Truth For Gameplay Rules

Use `origin/main:script.js` as the authoritative reference for:

- player rail-only movement and trail start rules
- spark routing on rail or trail paths
- QiX movement in empty field space
- captured-area grayscale reveal during play
- full image reveal and continue gating on level clear

Useful command:

```powershell
git show origin/main:script.js
```

## Release Guardrail

Do not publish another release on the strength of headless checks alone.

Before claiming parity or closing the issue, manually verify all of the following in a live build:

- captured cells reveal grayscale image detail during play
- level clear shows the full image and waits for Space or click
- the player cannot move freely across all safe tiles
- sparks stay on rail or trail paths
- QiX stay in empty field space
