#!/usr/bin/env python3
"""Minimal, read-only Waybar indicator for the study timer."""

import json
import os
from pathlib import Path

DATA_HOME = Path(
    os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")
).expanduser()

ACTIVE_FILE = DATA_HOME / "study-time" / "active.json"


def main() -> None:
    if ACTIVE_FILE.is_file():
        result = {
            "text": "⚠ STUDY TIMER ACTIVE",
            "class": "running",
        }
    else:
        result = {
            "text": "",
            "class": "inactive",
        }

    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
