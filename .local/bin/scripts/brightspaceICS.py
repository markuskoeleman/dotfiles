import sys
import json
import subprocess
from datetime import datetime, timezone
from zoneinfo import ZoneInfo


ICS_FILE = sys.argv[1]
TASKS_FILE = sys.argv[2]
PROJECT = sys.argv[3]


# ---------------------------------------------------------------------------
# ICS helpers
# ---------------------------------------------------------------------------

def unfold(lines):
    result = []

    for line in lines:
        line = line.rstrip("\r\n")

        if line.startswith((" ", "\t")) and result:
            result[-1] += line[1:]
        else:
            result.append(line)

    return result


def unescape(value):
    return (
        value
        .replace("\\n", "\n")
        .replace("\\N", "\n")
        .replace("\\,", ",")
        .replace("\\;", ";")
        .replace("\\\\", "\\")
    )


def parse_ics(path):

    with open(path, "r", encoding="utf-8-sig") as f:
        lines = unfold(f.readlines())

    events = []
    event = None

    for line in lines:

        if line == "BEGIN:VEVENT":
            event = {}
            continue

        if line == "END:VEVENT":
            if event is not None:
                events.append(event)

            event = None
            continue

        if event is None or ":" not in line:
            continue

        field, value = line.split(":", 1)
        field_name = field.split(";", 1)[0].upper()

        if field_name in {
            "SUMMARY",
            "LOCATION",
            "DTSTART",
        }:
            event[field_name] = unescape(value)

        if field_name == "DTSTART":

            for parameter in field.split(";")[1:]:
                if parameter.startswith("TZID="):
                    event["DTSTART_TZID"] = parameter[5:]

    return events


# ---------------------------------------------------------------------------
# Date helpers
# ---------------------------------------------------------------------------

def parse_due_date(value, tzid=None):

    # All-day event
    if len(value) == 8 and value.isdigit():
        dt = datetime.strptime(value, "%Y%m%d")
        return dt.strftime("%Y-%m-%d")

    # UTC
    if value.endswith("Z"):
        dt = datetime.strptime(
            value,
            "%Y%m%dT%H%M%SZ"
        )

        dt = dt.replace(tzinfo=timezone.utc)
        dt = dt.astimezone()

        return dt.strftime("%Y-%m-%dT%H:%M:%S")

    # Explicit timezone
    if tzid:
        try:
            dt = datetime.strptime(
                value,
                "%Y%m%dT%H%M%S"
            )

            dt = dt.replace(
                tzinfo=ZoneInfo(tzid)
            )

            dt = dt.astimezone()

            return dt.strftime("%Y-%m-%dT%H:%M:%S")

        except Exception:
            pass

    # Local/floating time
    dt = datetime.strptime(
        value,
        "%Y%m%dT%H%M%S"
    )

    return dt.strftime("%Y-%m-%dT%H:%M:%S")


def is_future(due):

    now = datetime.now().astimezone()

    if len(due) == 10:
        due_date = datetime.strptime(
            due,
            "%Y-%m-%d"
        ).date()

        return due_date >= now.date()

    due_datetime = datetime.strptime(
        due,
        "%Y-%m-%dT%H:%M:%S"
    )

    due_datetime = due_datetime.replace(
        tzinfo=now.tzinfo
    )

    return due_datetime >= now


# ---------------------------------------------------------------------------
# Load existing Taskwarrior tasks
# ---------------------------------------------------------------------------

with open(TASKS_FILE, "r", encoding="utf-8") as f:
    existing_tasks = json.load(f)


# We only need the descriptions.
existing_descriptions = {
    task.get("description", "")
    for task in existing_tasks
}


print(
    f"Found {len(existing_descriptions)} existing Taskwarrior tasks."
)


# ---------------------------------------------------------------------------
# Process Brightspace
# ---------------------------------------------------------------------------

events = parse_ics(ICS_FILE)

added = 0
skipped = 0


for event in events:

    summary = event.get("SUMMARY", "").strip()
    location = event.get("LOCATION", "").strip()
    start = event.get("DTSTART", "").strip()
    tzid = event.get("DTSTART_TZID")


    # Only assignments/events containing "- Due".
    if "- Due" not in summary:
        continue


    if not start:
        print(
            f"SKIP: {summary} (no due date)"
        )

        skipped += 1
        continue


    # Remove "- Due"
    title = summary

    if title.endswith("- Due"):
        title = title[:-5].strip()


    # Course + assignment
    if location:
        description = f"{location} - {title}"
    else:
        description = title


    # Parse due date
    try:
        due = parse_due_date(
            start,
            tzid
        )

    except Exception as e:
        print(
            f"SKIP: {description}: {e}"
        )

        skipped += 1
        continue


    # Only future assignments
    if not is_future(due):
        print(
            f"SKIP (past): {description}"
        )

        skipped += 1
        continue


    # -----------------------------------------------------------------------
    # THE IMPORTANT PART
    #
    # Check ALL Taskwarrior tasks, including completed ones.
    # -----------------------------------------------------------------------

    if description in existing_descriptions:

        print(
            f"EXISTS:  {description}"
        )

        continue


    # -----------------------------------------------------------------------
    # Create task
    # -----------------------------------------------------------------------

    result = subprocess.run(
        [
            "task",
            "add",
            description,
            f"due:{due}",
            f"project:{PROJECT}",
        ],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


    if result.returncode != 0:

        print(
            f"ERROR adding {description}: "
            f"{result.stderr.strip()}",
            file=sys.stderr
        )

        continue


    print(
        f"ADDED:   {description}"
    )

    # Add it to the set immediately.
    #
    # This protects against duplicate events inside the same ICS.
    existing_descriptions.add(description)

    added += 1


print()
print(
    f"Finished: {added} added, {skipped} skipped."
)
