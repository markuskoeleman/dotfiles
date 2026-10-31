#!/usr/bin/env python3
"""Small, local-first study timer with a curses interface."""
from __future__ import annotations

import curses
import json
import os
import uuid
from datetime import date, datetime, time, timedelta
from pathlib import Path
from typing import Any
import subprocess

CATEGORIES = ["Reading", "Coding", "Homework", "Problems"]
DATA_HOME = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")).expanduser()
DATA_DIR = DATA_HOME / "study-time"
ACTIVE_FILE = DATA_DIR / "active.json"
LOG_FILE = DATA_DIR / "sessions.jsonl"
_UNSET = object()

def notify_waybar() -> None:
    """Refresh the study module without restarting Waybar."""
    try:
        subprocess.run(
            ["pkill", "-RTMIN+8", "-x", "waybar"], # send signal to waybar
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
    except OSError:
        # Waybar might not be running, or pkill might be unavailable.
        pass

def ensure_data_dir() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)


def boot_id() -> str | None:
    try:
        return Path("/proc/sys/kernel/random/boot_id").read_text(encoding="utf-8").strip()
    except OSError:
        return None


def now_ts() -> float:
    return datetime.now().timestamp()


def read_active() -> dict[str, Any] | None:
    try:
        with ACTIVE_FILE.open("r", encoding="utf-8") as handle:
            value = json.load(handle)
        if not isinstance(value, dict) or not all(k in value for k in ("id", "category", "start")):
            raise ValueError("active timer state is missing required fields")
        if value["category"] not in CATEGORIES:
            raise ValueError("active timer has an unknown category")
        return value
    except FileNotFoundError:
        return None


def write_active(active: dict[str, Any] | None) -> None:
    ensure_data_dir()
    if active is None:
        try:
            ACTIVE_FILE.unlink()
        except FileNotFoundError:
            pass
        return
    temp = ACTIVE_FILE.with_suffix(".json.tmp")
    with temp.open("w", encoding="utf-8") as handle:
        json.dump(active, handle, ensure_ascii=False)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    temp.replace(ACTIVE_FILE)


def read_sessions() -> list[dict[str, Any]]:
    try:
        handle = LOG_FILE.open("r", encoding="utf-8")
    except FileNotFoundError:
        return []
    result: list[dict[str, Any]] = []
    with handle:
        for line in handle:
            try:
                item = json.loads(line)
                if (
                    isinstance(item, dict)
                    and item.get("category") in CATEGORIES
                    and isinstance(item.get("start"), (int, float))
                    and isinstance(item.get("end"), (int, float))
                    and item["end"] >= item["start"]
                ):
                    result.append(item)
            except (json.JSONDecodeError, TypeError):
                continue
    return result

def last_session_id() -> str | None:
    try:
        with LOG_FILE.open("rb") as f:
            f.seek(0, os.SEEK_END)
            if f.tell() < 2:
                return None

            f.seek(-2, os.SEEK_END)
            while f.tell() > 1:
                if f.read(1) == b"\n":
                    break
                f.seek(-2, os.SEEK_CUR)
            else:
                f.seek(0)

            record = json.loads(f.readline())
            return record.get("id") if isinstance(record, dict) else None

    except (OSError, json.JSONDecodeError):
        return None

def append_session(active: dict[str, Any], end: float, reason: str) -> None:
    ensure_data_dir()
    # Avoid duplicating a session if the process died after appending but before
    # clearing active.json.
    session_id = active["id"]
    if last_session_id() == session_id:
        return
    start = float(active["start"])
    end = max(start, float(end))
    record = {
        "id": session_id,
        "category": active["category"],
        "start": start,
        "end": end,
        "duration": end - start,
        "closed_by": reason,
    }
    with LOG_FILE.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n")
        handle.flush()
        os.fsync(handle.fileno())


def finish_active(
    active: dict[str, Any],
    end: float | None = None,
    reason: str = "stop",
) -> None:
    append_session(active, now_ts() if end is None else end, reason)
    write_active(None)

    # During a category switch, start_timer() will notify Waybar.
    if reason != "switch":
        notify_waybar()


def start_timer(category: str) -> dict[str, Any]:
    active = {
        "id": str(uuid.uuid4()),
        "category": category,
        "start": now_ts(),
        "boot_id": boot_id(),
    }
    write_active(active)
    notify_waybar()
    return active


def switch_timer(category: str) -> str:
    active = read_active()
    if active and active.get("boot_id") != boot_id() and active.get("boot_id") is not None:
        return "Resolve the timer from the previous boot first."
    if active and active["category"] == category:
        return f"Already tracking {category}."
    if active:
        finish_active(active, reason="switch")
    start_timer(category)
    return f"Now tracking {category}."


def fmt_duration(seconds: float, compact: bool = False) -> str:
    total = max(0, int(seconds))
    hours, remainder = divmod(total, 3600)
    minutes, secs = divmod(remainder, 60)
    if compact:
        if hours:
            return f"{hours}h {minutes:02d}m"
        return f"{minutes}m"
    return f"{hours:02d}:{minutes:02d}:{secs:02d}"


def local_text(ts: float, fmt: str = "%H:%M") -> str:
    return datetime.fromtimestamp(ts).strftime(fmt)


def bounds_for_day(day: date) -> tuple[float, float]:
    start = datetime.combine(day, time.min).timestamp()
    end = datetime.combine(day + timedelta(days=1), time.min).timestamp()
    return start, end


def all_intervals(
    now: float | None = None,
    sessions: list[dict[str, Any]] | None = None,
    active: Any = _UNSET,
) -> list[dict[str, Any]]:
    sessions = list(read_sessions() if sessions is None else sessions)
    if active is _UNSET:
        active = read_active()
    logged_ids = {item.get("id") for item in sessions}
    if active and active.get("id") not in logged_ids:
        # If the timer is from an earlier boot, don't silently include downtime.
        if active.get("boot_id") == boot_id() or active.get("boot_id") is None:
            sessions.append({
                "id": active.get("id"),
                "category": active["category"],
                "start": float(active["start"]),
                "end": now_ts() if now is None else now,
            })
    return sessions


def totals_between(
    start: float, end: float, now: float | None = None,
    sessions: list[dict[str, Any]] | None = None,
    active: Any = _UNSET,
) -> dict[str, float]:
    totals = {category: 0.0 for category in CATEGORIES}
    for item in all_intervals(now, sessions, active):
        overlap = max(0.0, min(float(item["end"]), end) - max(float(item["start"]), start))
        if overlap and item["category"] in totals:
            totals[item["category"]] += overlap
    return totals


def totals_for_day(
    day: date, now: float | None = None,
    sessions: list[dict[str, Any]] | None = None,
    active: Any = _UNSET,
) -> dict[str, float]:
    start, end = bounds_for_day(day)
    return totals_between(start, end, now, sessions, active)


def total_seconds(totals: dict[str, float]) -> float:
    return sum(totals.values())


def month_start(day: date) -> date:
    return date(day.year, day.month, 1)


def shift_month(day: date, step: int) -> date:
    index = day.year * 12 + day.month - 1 + step
    return date(index // 12, index % 12 + 1, 1)


def add_line(stdscr: Any, y: int, x: int, text: str, attr: int = 0) -> None:
    height, width = stdscr.getmaxyx()
    if y < 0 or y >= height or x >= width or x < 0:
        return
    clipped = str(text)[: max(0, width - x - 1)]
    try:
        stdscr.addstr(y, x, clipped, attr)
    except curses.error:
        pass


def init_colors() -> dict[str, int]:
    colors = {"title": curses.A_BOLD, "selected": curses.A_REVERSE, "active": curses.A_BOLD, "muted": curses.A_DIM, "warning": curses.A_BOLD}
    if curses.has_colors():
        try:
            curses.start_color()
            curses.use_default_colors()
            curses.init_pair(1, curses.COLOR_CYAN, -1)
            curses.init_pair(2, curses.COLOR_GREEN, -1)
            curses.init_pair(3, curses.COLOR_YELLOW, -1)
            colors["title"] |= curses.color_pair(1)
            colors["active"] |= curses.color_pair(2)
            colors["warning"] |= curses.color_pair(3)
        except curses.error:
            pass
    return colors


def stale(active: dict[str, Any] | None) -> bool:
    return bool(active and active.get("boot_id") and boot_id() and active["boot_id"] != boot_id())


def resolve_stale_timer(stdscr: Any, active: dict[str, Any], colors: dict[str, int]) -> bool:
    """Return True to continue to the main UI, False to quit."""
    while True:
        stdscr.erase()
        add_line(stdscr, 1, 2, "Study timer needs review", colors["warning"])
        add_line(stdscr, 3, 2, f"{active['category']} started at {local_text(float(active['start']), '%Y-%m-%d %H:%M:%S')}")
        add_line(stdscr, 5, 2, "This timer belongs to a previous boot; its shutdown time is unknown.")
        add_line(stdscr, 6, 2, "The downtime will not be counted automatically in reports.")
        add_line(stdscr, 8, 2, "[d] Discard the unfinished session")
        add_line(stdscr, 9, 2, "[s] Stop now (saves the full elapsed interval, including downtime)")
        add_line(stdscr, 10, 2, "[r] Restart this category from now (old unfinished time discarded)")
        add_line(stdscr, 12, 2, "[q] Quit without changing anything", colors["muted"])
        stdscr.refresh()
        key = stdscr.getch()
        # discard unfinished session
        if key in (ord("d"), ord("D")):
            write_active(None)
            notify_waybar()
            return True
        # stop the old session
        if key in (ord("s"), ord("S")):
            finish_active(active, reason="recovered-stop")
            return True
        # restart the category from now
        if key in (ord("r"), ord("R")):
            start_timer(active["category"])
            return True

        if key in (ord("q"), ord("Q"), 27):
            return False


def draw_timer(stdscr: Any, colors: dict[str, int], selected: int, message: str) -> None:
    now = now_ts()
    active = read_active()
    add_line(stdscr, 0, 2, "STUDY TIME  /  TIMER", colors["title"])
    if active:
        elapsed = max(0.0, now - float(active["start"]))
        add_line(stdscr, 2, 2, f"TRACKING  {active['category']}", colors["active"])
        add_line(stdscr, 3, 2, fmt_duration(elapsed), colors["active"] | curses.A_BOLD)
        add_line(stdscr, 4, 2, f"Started {local_text(float(active['start']), '%H:%M:%S')}", colors["muted"])
    else:
        add_line(stdscr, 2, 2, "No timer running", colors["muted"])
        add_line(stdscr, 3, 2, "Choose a category below to start.")
    add_line(stdscr, 6, 2, "CATEGORIES   (press 1-4, or j/k then Enter)", colors["title"])
    for i, category in enumerate(CATEGORIES):
        marker = ">" if i == selected else " "
        current = "  * tracking" if active and active["category"] == category else ""
        attr = colors["selected"] if i == selected else 0
        add_line(stdscr, 8 + i, 3, f"{marker} {i + 1}. {category:<10}{current}", attr)
    if message:
        add_line(stdscr, 14, 2, message, colors["muted"])
    add_line(stdscr, 18, 2, "j/k move   Enter start/switch   1-4 start/switch   s stop", colors["muted"])
    add_line(stdscr, 19, 2, "h/l views   c calendar   r reports   q quit", colors["muted"])


def draw_reports(stdscr: Any, colors: dict[str, int], message: str) -> None:
    now = now_ts()
    sessions = read_sessions()
    active = read_active()
    today = date.today()
    day_start, day_end = bounds_for_day(today)
    week_start_date = today - timedelta(days=today.weekday())
    week_start = datetime.combine(week_start_date, time.min).timestamp()
    month_start_date = month_start(today)
    month_start_ts = datetime.combine(month_start_date, time.min).timestamp()
    periods = [
        ("TODAY", day_start, day_end),
        ("THIS WEEK", week_start, now),
        ("THIS MONTH", month_start_ts, now),
    ]
    add_line(stdscr, 0, 2, "STUDY TIME  /  REPORTS", colors["title"])
    y = 3
    for title, start, end in periods:
        totals = totals_between(start, end, now, sessions, active)
        add_line(stdscr, y, 2, title, colors["title"])
        y += 1
        for category in CATEGORIES:
            add_line(stdscr, y, 4, f"{category:<10} {fmt_duration(totals[category])}")
            y += 1
        add_line(stdscr, y, 4, f"Total      {fmt_duration(total_seconds(totals))}", colors["active"])
        y += 2
    if message:
        add_line(stdscr, y + 1, 2, message, colors["muted"])
    add_line(stdscr, y + 3, 2, "h/l views   t timer   c calendar   r refresh   q quit", colors["muted"])


def draw_calendar(stdscr: Any, colors: dict[str, int], shown_month: date, message: str) -> None:
    import calendar
    cal = calendar.Calendar(firstweekday=0)  # Monday first
    today = date.today()
    sessions = read_sessions()
    active = read_active()
    calendar_now = now_ts()
    add_line(stdscr, 0, 2, f"STUDY TIME  /  CALENDAR  /  {shown_month.strftime('%B %Y')}", colors["title"])
    add_line(stdscr, 2, 2, "Mo       Tu       We       Th       Fr       Sa       Su", colors["muted"])
    weeks = cal.monthdatescalendar(shown_month.year, shown_month.month)
    y = 4
    cell_width = 8
    for week in weeks:
        for col, day in enumerate(week):
            x = 2 + col * cell_width
            if day.month != shown_month.month:
                cell = "        "
                attr = colors["muted"]
            else:
                total = total_seconds(totals_for_day(day, now=calendar_now, sessions=sessions, active=active))
                if total >= 4 * 3600:
                    mark = "#"
                elif total >= 2 * 3600:
                    mark = ":"
                elif total > 0:
                    mark = "."
                else:
                    mark = " "
                cell = f"{day.day:2d} {mark}    "
                attr = curses.A_REVERSE if day == today else (colors["active"] if total > 0 else 0)
            add_line(stdscr, y, x, cell, attr)
        y += 2
    add_line(stdscr, y + 1, 2, "Key: . under 2h   : 2-4h   # 4h+", colors["muted"])
    shown_totals = totals_for_day(today if today.month == shown_month.month and today.year == shown_month.year else date(shown_month.year, shown_month.month, 1), now=calendar_now, sessions=sessions, active=active)
    label_day = today if today.month == shown_month.month and today.year == shown_month.year else date(shown_month.year, shown_month.month, 1)
    add_line(stdscr, y + 3, 2, f"{label_day.strftime('%d %b')}: {fmt_duration(total_seconds(shown_totals))}")
    if message:
        add_line(stdscr, y + 5, 2, message, colors["muted"])
    add_line(stdscr, y + 7, 2, "h/l views   [ ] month   t timer   r reports   q quit", colors["muted"])


def run(stdscr: Any) -> None:
    colors = init_colors()
    try:
        curses.curs_set(0)
    except curses.error:
        pass
    stdscr.keypad(True)
    stdscr.timeout(1000)
    ensure_data_dir()
    try:
        active = read_active()
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        stdscr.erase()
        add_line(stdscr, 1, 2, "Could not read active timer state", colors["warning"])
        add_line(stdscr, 3, 2, str(exc))
        add_line(stdscr, 5, 2, f"Inspect: {ACTIVE_FILE}")
        add_line(stdscr, 7, 2, "Press q to exit.")
        stdscr.refresh()
        while stdscr.getch() not in (ord("q"), ord("Q")):
            pass
        return
    if active is not None and stale(active):
        if not resolve_stale_timer(stdscr, active, colors):
            return

    view = "timer"
    selected = 0
    shown_month = month_start(date.today())
    message = ""
    dirty = True
    while True:
        if dirty or view == "timer":
            stdscr.erase()
            try:
                if view == "timer":
                    draw_timer(stdscr, colors, selected, message)
                elif view == "reports":
                    draw_reports(stdscr, colors, message)
                else:
                    draw_calendar(stdscr, colors, shown_month, message)
            except (OSError, json.JSONDecodeError, ValueError) as exc:
                add_line(stdscr, 1, 2, f"Data error: {exc}", colors["warning"])
            stdscr.refresh()
            dirty = False
        key = stdscr.getch()
        if key == -1:
            continue
        if key in (ord("q"), ord("Q")):
            break
        dirty = True
        if key in (curses.KEY_DOWN, ord("j")):
            selected = (selected + 1) % len(CATEGORIES)
            message = ""
        elif key in (curses.KEY_UP, ord("k")):
            selected = (selected - 1) % len(CATEGORIES)
            message = ""
        elif key in (ord("1"), ord("2"), ord("3"), ord("4")):
            message = switch_timer(CATEGORIES[int(chr(key)) - 1])
        elif key in (curses.KEY_ENTER, 10, 13):
            message = switch_timer(CATEGORIES[selected])
        elif key in (ord("s"), ord("S")):
            active = read_active()
            if active:
                finish_active(active, reason="stop")
                message = f"Stopped {active['category']}."
            else:
                message = "No timer is running."
        elif key in (ord("t"), ord("T")):
            view, message = "timer", ""
        elif key in (ord("r"), ord("R")):
            view, message = "reports", ""
        elif key in (ord("c"), ord("C")):
            view, message = "calendar", ""
            shown_month = month_start(date.today())
        elif key in (ord("h"), ord("H")):
            view = {"timer": "calendar", "calendar": "reports", "reports": "timer"}[view]
            message = ""
        elif key in (ord("l"), ord("L")):
            view = {"timer": "reports", "reports": "calendar", "calendar": "timer"}[view]
            message = ""
        elif key == ord("[") and view == "calendar":
            shown_month = shift_month(shown_month, -1)
        elif key == ord("]") and view == "calendar":
            shown_month = shift_month(shown_month, 1)
        elif key == curses.KEY_RESIZE:
            pass


def main() -> None:
    try:
        curses.wrapper(run)
    except KeyboardInterrupt:
        # Leaving the UI never stops a timer.
        pass
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        raise SystemExit(f"study: {exc}") from exc


if __name__ == "__main__":
    main()
