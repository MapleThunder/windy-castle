# Windy Castle

A remake of Rick Saada's *Castle of the Winds* (1993) in Godot 4. The end goal is both games, *Part I: A Question of Vengeance* and *Part II: Lifthransir's Bane*, as one continuous game. It keeps the original's rules, monsters, items and dungeons, with a modern 2D look and optional quality-of-life features.

Work in progress. The first milestone is a vertical slice: the town of Hamlet and the first mine levels.

## Play

Needs Godot 4.7 or newer on your `PATH` as `godot`.

```sh
./play.sh
```

You can also launch **Windy Castle** from your application menu.

## Controls

The original's keys work as they did in 1993, and every menu item from its menu bar has a shortcut. Press **?** in game for the full list, built from your current bindings. Rebind keys with **F11** or from Options.

| Keys | Action |
|---|---|
| Numpad, arrows, or h j k l y u b n | Move (attack by moving into a monster, open doors by walking into them) |
| Shift + direction | Run until something interesting happens |
| Numpad 5 / . | Wait |
| g · s · o · c | Get · Search · Open · Close |
| r / Shift+R | Rest until healed |
| < / > | Climb up / down stairs |
| i | Inventory (drag and drop, or arrows + Enter / E equip / D drop / U remove) |
| m · F2 · F4 | Large map · Character · Message log |
| Ctrl+S · Ctrl+Shift+S · Ctrl+O · Ctrl+N | Save · Save as · Load · New game |
| F1 · ? · F10 · F11 | Help (the original help file) · Keys · Options · Rebind |

## Quality-of-life options

All are in Options (F10), and each can be turned off on its own:

- Item tooltips
- Letter movement keys (h j k l y u b n), on by default as in the original
- Click to move
- Pick up gold automatically
- Floating damage numbers

## What's faithful and what's not yet

- **From the original:** monster and item names, the item table (armour values, weapon classes, weights, bulk, container capacities), the keyboard commands, the menu structure, the help text, the art and the messages.
- **Placeholders, marked `ASSUMED` in the code:** monster stats, combat numbers, character creation limits, level generation odds and the town layout. They'll be replaced as the original's rules are recovered (`grep -rn ASSUMED engine/`).

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
