#!/usr/bin/env bash
# Regenerate data/ and assets/original/ from the original game in reference/.
set -euo pipefail
cd -- "$(dirname -- "$(readlink -f -- "$0")")/../.."
GAME=reference/win31/games/drive-c/castwind/castle1
python3 -I tools/extract/ne_resources.py --exe "$GAME/CASTLE1.EXE" --out-root .
python3 -I tools/extract/hlp_text.py --hlp "$GAME/CASTLE1.HLP" --out-root .
python3 -I tools/extract/tables.py --exe "$GAME/CASTLE1.EXE" --out-root .
python3 -I tools/extract/manifest.py --names tools/extract/icon_names.json --out-root .
