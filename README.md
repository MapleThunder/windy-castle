# Castle of the Winds: Remake

A remake of Rick Saada's *Castle of the Winds* (1993) in Godot 4. It keeps the original's rules, monsters, items and dungeons, with a modern 2D look and optional quality-of-life features.

Work in progress. The first milestone is a vertical slice: the town of Hamlet and the first mine levels.

## Play

Needs Godot 4.7 or newer on your `PATH` as `godot`.

```sh
./play.sh
```

## Test

```sh
godot --headless --path . -s tests/run_tests.gd
godot --headless --path . -s tests/run_tests.gd -- --filter=fov   # subset
python3 -I -m unittest discover -s tools/extract -p 'test_*.py'  # extractors
```

## Layout

| Path | What |
|---|---|
| `engine/` | Game rules: plain GDScript, no scene nodes. Actions go in, events come out. |
| `view/` | Rendering, lighting, animation, UI, input. |
| `data/` | Monster, item, map and help data extracted from the original game. |
| `assets/original/` | Original 32×32 art extracted from the game, used as the default art pack. |
| `tools/extract/` | Python scripts that regenerate `data/` and `assets/original/`. |
| `tests/` | Headless engine tests. |

## Re-extracting assets

`data/` and `assets/original/` are committed, so you don't need the original game to play. To regenerate them, put the original Windows 3.1 install under `reference/win31/games/drive-c/castwind/` (local only, git-ignored) and run `tools/extract/extract_all.sh`.
