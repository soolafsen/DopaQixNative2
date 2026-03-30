# DopaQixNative2

Native Godot 4 Windows port of the DopaQiX web game on `main`, rebuilt to stay close to the original gameplay loop, board framing, reveal mechanic, pickups, and synth-heavy arcade feel while shipping as a simple Windows zip bundle.

<p align="center">
  <img src="docs/frontpage.png" alt="DopaQixNative2 gameplay illustration" width="960">
</p>

> TODO: Better reveal images coming.

## Play Now

1. Go to [Releases](https://github.com/soolafsen/DopaQixNative2/releases/latest).
2. Download `DopaQixNative2-win64.zip`.
3. Unzip it.
4. Open the extracted folder and double-click `DopaQixNative2.exe`.

No Godot install is required for players.

## Controls

- `WASD` or arrow keys: move on the rail and cut into the field
- `Space` or `Enter`: start, continue after level clear, or restart after game over
- `Shift`: faster risky carve while drawing
- `Esc` or `P`: pause or resume
- `Q`: quit immediately
- `M`: toggle music

## Development

- Source run: open the repo in Godot 4.6+ and run `main.tscn`
- Quick verification: `godot --headless --path . --quit-after 1`
- Windows export: `powershell -ExecutionPolicy Bypass -File .\scripts\export-windows.ps1`

More detail lives in [docs/development.md](./docs/development.md).

## Notes

- The Godot project at the repo root is the shipping source of truth.
- Ralph tracking for this repo lives in `.agents/tasks/prd-dopaqix-native2.json`.
- Audio assets in `assets/audio` are third-party source files used for the calmer cut SFX and music loop.
