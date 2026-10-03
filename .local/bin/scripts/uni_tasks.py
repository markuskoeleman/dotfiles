#!/usr/bin/env python3

import argparse
import curses
import json
import re
import subprocess
import sys
import textwrap
from pathlib import Path
from datetime import datetime, timedelta, timezone
from typing import Any


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# DEFAULT_FILTER = ["project:brightspace", "status:pending"] # uncomment if you only want brightspace tasks
DEFAULT_FILTER = ["status:pending"]

# Taskwarrior's DUE virtual tag is controlled by the `due` setting and is
# seven days by default. We read the user's actual setting when possible.
DEFAULT_DUE_DAYS = 7

TASK_ROW_RE = re.compile(r"^\s*(\d+)\s+")
CONFIG_DUE_RE = re.compile(r"^\s*due\s*=\s*(\d+)")

UDA_UID = "brightspace_uid"
UDA_DESCRIPTION = "brightspace_description"
UDA_URL = "brightspace_url"
UDA_MATERIALS = "brightspace_materials"


# ---------------------------------------------------------------------------
# Taskwarrior interaction
# ---------------------------------------------------------------------------


def run_task(*args: str) -> subprocess.CompletedProcess[str]:
    """Run Taskwarrior without involving a shell."""
    return subprocess.run(
        ["task", *args],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def task_config_args() -> list[str]:
    """Settings needed for predictable machine-readable output."""
    return [
        "rc.color=off",
        "rc.verbose=nothing",
        "rc.confirmation=no",
    ]


def export_tasks(filters: list[str]) -> list[dict[str, Any]]:
    """Export tasks as JSON."""
    result = run_task(
        *task_config_args(),
        *filters,
        "export",
    )

    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "task export failed")

    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Could not parse Taskwarrior export: {exc}") from exc

    if not isinstance(data, list):
        raise RuntimeError("Taskwarrior export did not return a JSON array")

    return data


def get_task_report(filters: list[str], width: int) -> list[str]:
    """Get Taskwarrior's normal report, without color escape sequences."""
    result = run_task(
        *task_config_args(),
        f"rc.defaultwidth={max(width, 40)}",
        *filters,
    )

    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "task report failed")

    return result.stdout.splitlines()


def get_taskwarrior_due_days() -> int:
    """Read Taskwarrior's `due` configuration; fall back to its documented default."""
    result = run_task(
        *task_config_args(),
        "show",
        "due",
    )

    if result.returncode == 0:
        for line in result.stdout.splitlines():
            match = CONFIG_DUE_RE.match(line)
            if match:
                return int(match.group(1))

    return DEFAULT_DUE_DAYS


def task_action(task_uuid: str, *action: str) -> None:
    result = run_task(
        *task_config_args(),
        task_uuid,
        *action,
    )

    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "Taskwarrior command failed")


def open_url(url: str) -> None:
    """Open a URL using the desktop's normal URL handler."""
    if not url:
        raise RuntimeError("This task does not have that Brightspace URL")

    try:
        subprocess.Popen(
            ["xdg-open", url],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except FileNotFoundError as exc:
        raise RuntimeError("xdg-open was not found") from exc


# ---------------------------------------------------------------------------
# Report parsing
# ---------------------------------------------------------------------------


def parse_report(lines: list[str]) -> tuple[list[str], list[str], list[int]]:
    """Separate Taskwarrior's report header from its task rows."""
    task_lines: list[str] = []
    task_ids: list[int] = []
    header_lines: list[str] = []

    first_task_index: int | None = None

    for index, line in enumerate(lines):
        if TASK_ROW_RE.match(line):
            first_task_index = index
            break

    if first_task_index is None:
        return lines, [], []

    header_lines = lines[:first_task_index]

    for line in lines[first_task_index:]:
        match = TASK_ROW_RE.match(line)
        if not match:
            continue

        task_lines.append(line)
        task_ids.append(int(match.group(1)))

    return header_lines, task_lines, task_ids


# ---------------------------------------------------------------------------
# Date / display helpers
# ---------------------------------------------------------------------------


def parse_task_due(value: Any) -> datetime | None:
    """Parse Taskwarrior's exported ISO due date."""
    if not value:
        return None

    text = str(value)

    try:
        if text.endswith("Z"):
            return datetime.fromisoformat(text[:-1] + "+00:00")

        dt = datetime.fromisoformat(text)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=datetime.now().astimezone().tzinfo)
        return dt
    except ValueError:
        return None


def task_is_due_or_overdue(task: dict[str, Any], due_days: int) -> bool:
    """
    Match Taskwarrior's DUE concept: due within `due` days, including overdue.

    Taskwarrior documents DUE as a virtual tag for tasks due within the next
    configured number of days, with the default being seven. Overdue tasks are
    also treated as urgent for display here.
    """
    due = parse_task_due(task.get("due"))
    if due is None:
        return False

    now = datetime.now().astimezone()
    local_due = due.astimezone(now.tzinfo)

    return local_due <= now + timedelta(days=due_days)


def format_due(task: dict[str, Any]) -> str:
    value = task.get("due")
    if not value:
        return ""

    dt = parse_task_due(value)
    if dt is None:
        return str(value)

    return dt.astimezone().strftime("%a %d %b %H:%M")


# ---------------------------------------------------------------------------
# TUI drawing helpers
# ---------------------------------------------------------------------------


def safe_addnstr(
    stdscr: curses.window,
    y: int,
    x: int,
    text: str,
    attr: int = 0,
    max_width: int | None = None,
) -> None:
    """Draw text without writing outside the terminal."""
    height, width = stdscr.getmaxyx()

    if y < 0 or y >= height or x < 0 or x >= width:
        return

    available = width - x
    if max_width is not None:
        available = min(available, max_width)

    if available <= 0:
        return

    try:
        stdscr.addnstr(y, x, text, available, attr)
    except curses.error:
        pass


def draw_status(stdscr: curses.window, message: str, error: bool = False) -> None:
    height, width = stdscr.getmaxyx()
    if height <= 0 or width <= 0:
        return

    # Always clear the complete footer first. This prevents remnants of a
    # longer previous status/search prompt from staying on screen.
    try:
        stdscr.move(height - 1, 0)
        stdscr.clrtoeol()
    except curses.error:
        pass

    attr = curses.A_BOLD
    if error:
        attr |= curses.A_REVERSE

    safe_addnstr(stdscr, height - 1, 0, message, attr, width)


def confirm(stdscr: curses.window, prompt: str) -> bool:
    """Ask for an explicit y/n confirmation."""
    height, width = stdscr.getmaxyx()
    message = f"{prompt}  [y/N]"

    draw_status(stdscr, message)
    stdscr.refresh()

    while True:
        key = stdscr.get_wch()

        if isinstance(key, str):
            if key.lower() == "y":
                return True
            if key.lower() in {"n", "\x1b"}:
                return False

        # Ctrl-C / Ctrl-G cancel.
        if isinstance(key, int) and key in {3, 7}:
            return False

        # Redraw prompt if curses resized/redrew underneath us.
        if height > 0 and width > 0:
            try:
                stdscr.touchline(height - 1, True)
                stdscr.refresh()
            except curses.error:
                pass


def draw_wrapped(
    stdscr: curses.window,
    y: int,
    x: int,
    width: int,
    text: str,
    attr: int = 0,
    max_lines: int | None = None,
) -> int:
    """
    Draw wrapped text, deliberately breaking long URLs when necessary.

    A wide terminal will therefore show the complete URL on one line, which
    is ideal for Foot's URL selection. On narrower terminals the text is
    wrapped rather than replaced with ellipses.
    """
    if width <= 1 or y < 0:
        return y

    paragraphs = text.splitlines() or [""]
    lines: list[str] = []

    for paragraph in paragraphs:
        if not paragraph:
            lines.append("")
            continue

        wrapped = textwrap.wrap(
            paragraph,
            width=width,
            replace_whitespace=False,
            drop_whitespace=False,
            break_long_words=True,
            break_on_hyphens=False,
        )
        lines.extend(wrapped or [""])

    for line in lines:
        if max_lines is not None and y >= max_lines:
            break
        safe_addnstr(stdscr, y, x, line, attr, width)
        y += 1

    return y


# ---------------------------------------------------------------------------
# Sync feedback
# ---------------------------------------------------------------------------


def summarize_sync_output(output: str) -> str:
    """Turn the Brightspace sync log into a compact human-readable status."""
    added = sum(1 for line in output.splitlines() if line.startswith("ADDED:"))
    updated = sum(1 for line in output.splitlines() if line.startswith("UPDATE:"))
    migrated = sum(1 for line in output.splitlines() if line.startswith("MIGRATE:"))
    exists = sum(1 for line in output.splitlines() if line.startswith("EXISTS:"))
    skipped = sum(1 for line in output.splitlines() if line.startswith("SKIP"))

    parts: list[str] = []

    checked = exists + updated
    if checked:
        parts.append(f"{checked} checked")
    if added:
        parts.append(f"{added} added")
    if updated:
        parts.append(f"{updated} updated")
    if migrated:
        parts.append(f"{migrated} migrated")
    if skipped:
        parts.append(f"{skipped} skipped")

    if not parts:
        return "✓ Brightspace synced · no changes"

    return "✓ Brightspace synced · " + " · ".join(parts)


# ---------------------------------------------------------------------------
# Main application
# ---------------------------------------------------------------------------


class UniTaskUI:
    def __init__(self, stdscr: curses.window, filters: list[str]) -> None:
        self.stdscr = stdscr
        self.filters = filters

        self.tasks: list[dict[str, Any]] = []
        self.tasks_by_id: dict[int, dict[str, Any]] = {}
        self.task_lines: list[str] = []
        self.task_ids: list[int] = []
        self.header_lines: list[str] = []

        self.selected = 0
        self.top = 0
        self.due_days = DEFAULT_DUE_DAYS

        self.status_message = ""
        self.status_error = False

        # Only our immediately preceding `done` action can be undone.
        self.undo_uuid: str | None = None

        # Vim-style incremental search state.
        self.search_query = ""
        self.search_active = False
        self.pending_g = False

        self.load()

    def load(self) -> None:
        """Refresh task data and the normal Taskwarrior report."""
        _, width = self.stdscr.getmaxyx()

        old_selected_id: int | None = None
        if self.tasks and 0 <= self.selected < len(self.tasks):
            old_selected_id = self.tasks[self.selected].get("id")

        try:
            tasks = export_tasks(self.filters)
            report = get_task_report(self.filters, width)
            self.due_days = get_taskwarrior_due_days()
        except Exception as exc:
            self.status_message = str(exc)
            self.status_error = True
            return

        tasks_by_id: dict[int, dict[str, Any]] = {}
        for task in tasks:
            task_id = task.get("id")
            if isinstance(task_id, int):
                tasks_by_id[task_id] = task

        header_lines, task_lines, task_ids = parse_report(report)

        valid_ids = [task_id for task_id in task_ids if task_id in tasks_by_id]
        valid_lines: list[str] = []
        valid_report_ids: list[int] = []

        for line in task_lines:
            match = TASK_ROW_RE.match(line)
            if not match:
                continue

            task_id = int(match.group(1))
            if task_id in tasks_by_id:
                valid_lines.append(line)
                valid_report_ids.append(task_id)

        self.tasks_by_id = tasks_by_id
        # Keep task data in exactly the same order as the Taskwarrior report.
        self.tasks = [tasks_by_id[task_id] for task_id in valid_report_ids]
        self.task_lines = valid_lines
        self.task_ids = valid_report_ids
        self.header_lines = header_lines

        if not self.tasks:
            self.selected = 0
        elif old_selected_id in valid_ids:
            self.selected = valid_ids.index(old_selected_id)
        else:
            self.selected = min(self.selected, len(self.tasks) - 1)

        self.ensure_selection_visible()

    def ensure_selection_visible(self) -> None:
        height, _ = self.stdscr.getmaxyx()

        # Reserve one line for the Taskwarrior header and a detail area. The
        # detail area is adaptive; keeping at least six task rows visible makes
        # the interface useful even on small terminals.
        header_height = len(self.header_lines)
        detail_height = self.detail_height(height)
        footer_height = 2
        usable_rows = max(1, height - header_height - detail_height - footer_height - 1)

        if self.selected < self.top:
            self.top = self.selected

        if self.selected >= self.top + usable_rows:
            self.top = self.selected - usable_rows + 1

        max_top = max(0, len(self.task_lines) - usable_rows)
        self.top = min(self.top, max_top)

    def detail_height(self, terminal_height: int) -> int:
        """Height reserved for the selected-task detail area."""
        if terminal_height < 20:
            return 6
        if terminal_height < 30:
            return 8
        return 20

    def current_task(self) -> dict[str, Any] | None:
        if not self.tasks:
            return None
        if not 0 <= self.selected < len(self.tasks):
            return None
        return self.tasks[self.selected]

    def current_task_label(self) -> str:
        task = self.current_task()
        return str(task.get("description", "")) if task else ""

    def draw_task_row(self, y: int, index: int, line: str) -> None:
        task = self.tasks[index]
        due_or_overdue = task_is_due_or_overdue(task, self.due_days)
        selected = index == self.selected

        # Preserve the useful visual signal from normal Taskwarrior: tasks
        # considered DUE/OVERDUE are red. Selection is indicated by bold+
        # underline so we don't destroy that red urgency cue.
        attr = 0

        if curses.has_colors():
            # Keep Taskwarrior's useful red DUE cue even on the selected row.
            if selected and not due_or_overdue:
                attr |= curses.color_pair(2)
            elif due_or_overdue:
                attr |= curses.color_pair(1)
        else:
            if selected:
                attr |= curses.A_BOLD | curses.A_UNDERLINE

        if selected:
            attr |= curses.A_BOLD | curses.A_UNDERLINE

        safe_addnstr(self.stdscr, y, 0, line, attr)

    def draw_details(self, start_y: int) -> None:
        height, width = self.stdscr.getmaxyx()

        # Leave one completely empty line above the footer. The footer itself
        # occupies the final terminal line.
        detail_bottom = max(0, height - 2)

        # Separator.
        if start_y < detail_bottom:
            separator = "─" * max(1, width)
            safe_addnstr(self.stdscr, start_y, 0, separator)
            start_y += 1

        if start_y >= detail_bottom:
            return

        task = self.current_task()
        if task is None:
            safe_addnstr(
                self.stdscr,
                start_y,
                0,
                "No task selected.",
                curses.A_BOLD,
            )
            return

        title = str(task.get("description", ""))
        due = format_due(task)
        materials = str(task.get(UDA_MATERIALS, "") or "")
        event_url = str(task.get(UDA_URL, "") or "")
        description = str(task.get(UDA_DESCRIPTION, "") or "")

        safe_addnstr(
            self.stdscr,
            start_y,
            0,
            title,
            curses.A_BOLD,
        )
        y = start_y + 1

        if due and y < detail_bottom:
            safe_addnstr(
                self.stdscr,
                y,
                0,
                f"Due: {due}",
                curses.A_BOLD,
            )
            y += 1

        fields: list[tuple[str, str]] = []

        if materials:
            fields.append(("Materials URL", materials))

        if event_url:
            fields.append(("Brightspace URL", event_url))

        if description:
            fields.append(("Description", description))

        for label, value in fields:
            if y >= detail_bottom:
                break

            safe_addnstr(
                self.stdscr,
                y,
                0,
                f"{label}: ",
                curses.A_BOLD,
            )
            y += 1

            remaining_height = max(0, detail_bottom - y)
            if remaining_height <= 0:
                break

            y = draw_wrapped(
                self.stdscr,
                y,
                2,
                max(1, width - 2),
                value,
                max_lines=detail_bottom,
            )

    def draw(self) -> None:
        self.stdscr.erase()
        height, width = self.stdscr.getmaxyx()

        y = 0

        # Header exactly as Taskwarrior generated it.
        for line in self.header_lines:
            if y >= height - 1:
                break
            safe_addnstr(self.stdscr, y, 0, line)
            y += 1

        detail_height = self.detail_height(height)
        footer_height = 2
        task_area_height = max(1, height - y - detail_height - footer_height)

        if not self.tasks:
            safe_addnstr(
                self.stdscr,
                y,
                0,
                "No pending university tasks.",
                curses.A_BOLD,
            )
        else:
            for offset in range(task_area_height):
                index = self.top + offset
                if index >= len(self.task_lines):
                    break

                self.draw_task_row(
                    y + offset,
                    index,
                    self.task_lines[index],
                )

        detail_start = y + task_area_height
        self.draw_details(detail_start)

        if self.status_message:
            draw_status(
                self.stdscr,
                self.status_message,
                self.status_error,
            )
        else:
            draw_status(
                self.stdscr,
                "j/k move  gg/G first/last  / search  d done  u undo  s start/stop  o materials  b Brightspace  r refresh  R sync  q quit",
            )

        self.stdscr.refresh()

    # -----------------------------------------------------------------------
    # Navigation
    # -----------------------------------------------------------------------

    def move(self, delta: int) -> None:
        if not self.tasks:
            return

        self.selected = max(
            0,
            min(len(self.tasks) - 1, self.selected + delta),
        )
        self.ensure_selection_visible()
        self.status_message = ""
        self.status_error = False

    def first(self) -> None:
        if self.tasks:
            self.selected = 0
            self.ensure_selection_visible()
            self.status_message = ""
            self.status_error = False

    def last(self) -> None:
        if self.tasks:
            self.selected = len(self.tasks) - 1
            self.ensure_selection_visible()
            self.status_message = ""
            self.status_error = False

    def page(self, direction: int) -> None:
        if not self.tasks:
            return

        height, _ = self.stdscr.getmaxyx()
        page = max(
            1,
            height
            - len(self.header_lines)
            - self.detail_height(height)
            - 3,
        )

        self.selected = max(
            0,
            min(len(self.tasks) - 1, self.selected + direction * page),
        )
        self.ensure_selection_visible()
        self.status_message = ""
        self.status_error = False

    # -----------------------------------------------------------------------
    # Search
    # -----------------------------------------------------------------------

    def task_matches(self, task: dict[str, Any], query: str) -> bool:
        if not query:
            return True

        haystack_parts = [
            str(task.get("description", "")),
            str(task.get("project", "")),
            str(task.get(UDA_DESCRIPTION, "") or ""),
        ]
        haystack = "\n".join(haystack_parts).lower()
        return query.lower() in haystack

    def search_prompt(self) -> None:
        """Enter a small Vim-style / search prompt."""
        self.search_active = True
        query = list(self.search_query)

        while True:
            try:
                height, width = self.stdscr.getmaxyx()
                prompt = "/" + "".join(query)

                # Clear the footer before drawing the search prompt so stale
                # status text can never leak into the prompt.
                try:
                    self.stdscr.move(height - 1, 0)
                    self.stdscr.clrtoeol()
                except curses.error:
                    pass

                safe_addnstr(
                    self.stdscr,
                    height - 1,
                    0,
                    prompt,
                    curses.A_BOLD,
                    max(1, width),
                )
                self.stdscr.move(
                    height - 1,
                    min(width - 1, len(prompt)),
                )
                self.stdscr.refresh()

                key = self.stdscr.get_wch()
            except curses.error:
                continue

            if isinstance(key, str):
                if key in ("\x1b", "\n"):
                    if key == "\n":
                        self.search_query = "".join(query)
                        self.search_active = False
                        if self.search_query:
                            self.search_next(1)
                        else:
                            self.status_message = "Search cleared."
                            self.status_error = False
                    else:
                        self.search_active = False
                        self.status_message = "Search cancelled."
                        self.status_error = False
                    return

                if key in ("\b", "\x7f"):
                    if query:
                        query.pop()
                    continue

                if key.isprintable():
                    query.append(key)
                    continue

            if isinstance(key, int) and key in {3, 7}:
                self.search_active = False
                return

    def search_next(self, direction: int = 1) -> None:
        if not self.search_query or not self.tasks:
            self.status_message = "No active search."
            self.status_error = False
            return

        count = len(self.tasks)
        for step in range(1, count + 1):
            index = (self.selected + direction * step) % count
            if self.task_matches(self.tasks[index], self.search_query):
                self.selected = index
                self.ensure_selection_visible()
                self.status_message = f"Search: {self.search_query}"
                self.status_error = False
                return

        self.status_message = f"Pattern not found: {self.search_query}"
        self.status_error = True

    # -----------------------------------------------------------------------
    # Actions
    # -----------------------------------------------------------------------

    def done(self) -> None:
        task = self.current_task()
        if task is None:
            return

        description = self.current_task_label()

        if not confirm(
            self.stdscr,
            f"Mark '{description}' as done?",
        ):
            self.status_message = "Cancelled."
            self.status_error = False
            return

        uuid = task.get("uuid")
        if not uuid:
            self.status_message = "Selected task has no UUID."
            self.status_error = True
            return

        try:
            task_action(str(uuid), "done")
        except Exception as exc:
            self.status_message = str(exc)
            self.status_error = True
            return

        self.undo_uuid = str(uuid)
        self.status_message = "Done. Press u to undo."
        self.status_error = False
        self.load()

    def undo(self) -> None:
        if not self.undo_uuid:
            self.status_message = "Nothing to undo."
            self.status_error = False
            return

        try:
            task_action(
                self.undo_uuid,
                "modify",
                "status:pending",
            )
        except Exception as exc:
            self.status_message = str(exc)
            self.status_error = True
            return

        self.status_message = "Undid last done action."
        self.status_error = False
        self.undo_uuid = None
        self.load()

    def toggle_start(self) -> None:
        task = self.current_task()
        if task is None:
            return

        uuid = task.get("uuid")
        if not uuid:
            return

        try:
            if task.get("start"):
                task_action(str(uuid), "stop")
                self.status_message = "Task stopped."
            else:
                task_action(str(uuid), "start")
                self.status_message = "Task started."

            self.status_error = False
            self.undo_uuid = None
            self.load()

        except Exception as exc:
            self.status_message = str(exc)
            self.status_error = True

    def sync_brightspace(self) -> None:
        """Run brightspace.sh and show a useful summary when it finishes."""
        script = Path(__file__).resolve().with_name("brightspace.sh")

        if not script.is_file():
            self.status_message = f"Brightspace sync script not found: {script}"
            self.status_error = True
            return

        self.status_message = "⟳ Syncing Brightspace…"
        self.status_error = False
        self.draw()

        try:
            result = subprocess.run(
                ["bash", str(script)],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        except OSError as exc:
            self.status_message = f"Brightspace sync could not start: {exc}"
            self.status_error = True
            return

        if result.returncode != 0:
            detail_lines = [
                line.strip()
                for line in result.stderr.splitlines()
                if line.strip()
            ]
            detail = detail_lines[-1] if detail_lines else "sync failed"
            self.status_message = f"✗ Brightspace sync failed · {detail}"
            self.status_error = True
            return

        # Reload Taskwarrior only after the sync has successfully finished.
        self.status_message = summarize_sync_output(result.stdout)
        self.status_error = False
        self.load()

    def refresh(self) -> None:
        """Reload Taskwarrior data without leaving a stale 'Refreshing…' footer."""
        self.status_message = "⟳ Refreshing…"
        self.status_error = False
        self.draw()

        self.load()

        if not self.status_error:
            # A plain refresh is silent once complete; the normal key bar
            # returns immediately instead of leaving 'Refreshing…' behind.
            self.status_message = ""

    def open_materials(self) -> None:
        task = self.current_task()
        if task is None:
            return

        url = str(task.get(UDA_MATERIALS, "") or "")
        if not url:
            url = str(task.get(UDA_URL, "") or "")

        try:
            open_url(url)
            self.status_message = "Opened materials URL."
            self.status_error = False
        except Exception as exc:
            self.status_message = str(exc)
            self.status_error = True

    def open_event(self) -> None:
        task = self.current_task()
        if task is None:
            return

        url = str(task.get(UDA_URL, "") or "")

        try:
            open_url(url)
            self.status_message = "Opened Brightspace event."
            self.status_error = False
        except Exception as exc:
            self.status_message = str(exc)
            self.status_error = True

    # -----------------------------------------------------------------------
    # Event loop
    # -----------------------------------------------------------------------

    def run(self) -> None:
        self.stdscr.keypad(True)
        curses.curs_set(0)
        self.stdscr.timeout(-1)

        if curses.has_colors():
            try:
                curses.start_color()
                curses.use_default_colors()

                # Pair 1: due/overdue rows. Red foreground, terminal default
                # background. Pair 2: selected row. Cyan foreground; selection
                # also gets bold + underline, while due rows retain their red
                # pair because selection styling is attribute-based.
                curses.init_pair(1, curses.COLOR_RED, -1)
                curses.init_pair(2, curses.COLOR_CYAN, -1)
            except curses.error:
                pass

        while True:
            self.draw()
            key = self.stdscr.get_wch()

            if isinstance(key, str):
                # Vim-style gg. A lone g arms the gg sequence; any other
                # subsequent key simply cancels it and is handled normally.
                if self.pending_g:
                    self.pending_g = False
                    if key == "g":
                        self.first()
                        continue

                if key == "q":
                    return
                if key == "j":
                    self.move(1)
                elif key == "k":
                    self.move(-1)
                elif key == "G":
                    self.last()
                elif key == "g":
                    self.pending_g = True
                    self.status_message = "g-"
                    self.status_error = False
                elif key == "/":
                    self.search_prompt()
                elif key == "n":
                    self.search_next(1)
                elif key == "N":
                    self.search_next(-1)
                elif key == "d":
                    self.done()
                elif key == "u":
                    self.undo()
                elif key == "s":
                    self.toggle_start()
                elif key == "o":
                    self.open_materials()
                elif key == "b":
                    self.open_event()
                elif key == "r":
                    self.refresh()
                elif key == "R":
                    self.sync_brightspace()
                elif key == "\x04":  # Ctrl-d
                    self.page(1)
                elif key == "\x15":  # Ctrl-u
                    self.page(-1)
                continue

            if key == curses.KEY_DOWN:
                self.move(1)
            elif key == curses.KEY_UP:
                self.move(-1)
            elif key == curses.KEY_NPAGE:
                self.page(1)
            elif key == curses.KEY_PPAGE:
                self.page(-1)
            elif key == curses.KEY_HOME:
                self.first()
            elif key == curses.KEY_END:
                self.last()
            elif key == curses.KEY_RESIZE:
                self.ensure_selection_visible()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Small Vim-oriented frontend for university Taskwarrior tasks."
    )
    parser.add_argument(
        "filter",
        nargs="*",
        help=(
            "Taskwarrior filter. Defaults to: "
            "status:pending"
        ),
    )

    args = parser.parse_args()
    filters = args.filter or DEFAULT_FILTER

    try:
        curses.wrapper(lambda stdscr: UniTaskUI(stdscr, filters).run())
    except KeyboardInterrupt:
        return 130
    except Exception as exc:
        print(f"uni-tasks: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
