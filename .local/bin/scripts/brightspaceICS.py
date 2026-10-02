#!/usr/bin/env python3

import sys
import json
import re
import subprocess
import time
from datetime import datetime, timezone
from zoneinfo import ZoneInfo


ICS_FILE = sys.argv[1]
TASKS_FILE = sys.argv[2]
PROJECT = sys.argv[3]


# ---------------------------------------------------------------------------
# Taskwarrior UDA names
# ---------------------------------------------------------------------------

UDA_UID = "brightspace_uid"
UDA_DESCRIPTION = "brightspace_description"
UDA_URL = "brightspace_url"
UDA_MATERIALS = "brightspace_materials"


# ---------------------------------------------------------------------------
# Taskwarrior helper
# ---------------------------------------------------------------------------

def run_task(*args):
    return subprocess.run(
        ["task", *args],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def modify_task(task, description, modifications):
    """
    Update an existing task.

    The description is passed as a normal Taskwarrior description.
    All Brightspace fields are passed as proper task attributes.
    """

    uuid = task.get("uuid")

    if not uuid:
        print(
            "ERROR: Existing task has no UUID.",
            file=sys.stderr,
        )
        return False

    args = [
        uuid,
        "modify",
        description,
    ]

    for key, value in modifications.items():
        args.append(f"{key}:{value}")

    result = run_task(*args)

    if result.returncode != 0:
        print(
            f"ERROR modifying task {uuid}: "
            f"{result.stderr.strip()}",
            file=sys.stderr,
        )
        return False

    return True


def add_task(
    description,
    due,
    brightspace_uid,
    brightspace_description,
    brightspace_url,
    brightspace_materials,
):
    """
    Create a new Brightspace task.

    The task description comes immediately after 'add'.
    The UDAs and other task attributes follow it.
    """

    args = [
        "add",
        description,
        f"due:{due}",
        f"project:{PROJECT}",
        f"{UDA_UID}:{brightspace_uid}",
        f"{UDA_DESCRIPTION}:{brightspace_description}",
        f"{UDA_URL}:{brightspace_url}",
        f"{UDA_MATERIALS}:{brightspace_materials}",
    ]

    result = run_task(*args)

    if result.returncode != 0:
        print(
            f"ERROR adding {description}: "
            f"{result.stderr.strip()}",
            file=sys.stderr,
        )
        return False

    return True


# ---------------------------------------------------------------------------
# ICS helpers
# ---------------------------------------------------------------------------

def unfold(lines):
    """
    Unfold RFC 5545 continuation lines.
    """

    result = []

    for line in lines:
        line = line.rstrip("\r\n")

        if line.startswith((" ", "\t")) and result:
            result[-1] += line[1:]
        else:
            result.append(line)

    return result


def unescape(value):
    """
    Decode common iCalendar TEXT escaping.
    """

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
            "UID",
            "SUMMARY",
            "LOCATION",
            "DESCRIPTION",
            "DTSTART",
            "URL",
            "RECURRENCE-ID",
        }:
            event[field_name] = unescape(value)

        if field_name == "DTSTART":

            for parameter in field.split(";")[1:]:

                if parameter.upper().startswith("TZID="):
                    event["DTSTART_TZID"] = (
                        parameter[5:].strip('"')
                    )

        if field_name == "RECURRENCE-ID":

            for parameter in field.split(";")[1:]:

                if parameter.upper().startswith("TZID="):
                    event["RECURRENCE_ID_TZID"] = (
                        parameter[5:].strip('"')
                    )

    return events


# ---------------------------------------------------------------------------
# Brightspace description / URL helpers
# ---------------------------------------------------------------------------

URL_RE = re.compile(
    r"https?://[^\s<>]+",
    re.IGNORECASE,
)


def clean_url(url):
    return url.rstrip(".,;:!?)]}>")


def extract_urls(text):

    if not text:
        return []

    return [
        clean_url(url)
        for url in URL_RE.findall(text)
    ]


def normalize_description(text):
    """
    Preserve the structure of the Brightspace description.

    Remove whitespace around lines and collapse multiple blank
    lines into a single blank line.
    """

    if not text:
        return ""

    result = []
    previous_blank = False

    for raw_line in text.splitlines():

        line = raw_line.strip()

        if not line:

            if result and not previous_blank:
                result.append("")

            previous_blank = True
            continue

        result.append(line)
        previous_blank = False

    # Remove trailing blank line.
    while result and result[-1] == "":
        result.pop()

    return "\n".join(result)


def extract_materials_url(description):
    """
    Brightspace examples seen so far use sections such as:

        Materials:
        Homework 4 - https://...

    or:

        Assignments:
        Homework 4 - https://...

    Return the first URL associated with those sections.
    """

    if not description:
        return ""

    lines = [
        line.strip()
        for line in description.splitlines()
        if line.strip()
    ]

    for index, line in enumerate(lines):

        lower = line.lower()

        if (
            "materials" in lower
            or "assignments" in lower
        ):

            urls = extract_urls(line)

            if urls:
                return urls[0]

            for following in lines[index + 1:index + 4]:

                if "view event" in following.lower():
                    break

                urls = extract_urls(following)

                if urls:
                    return urls[0]

    return ""


def extract_event_url(description):

    if not description:
        return ""

    for line in description.splitlines():

        if "view event" in line.lower():

            urls = extract_urls(line)

            if urls:
                return urls[0]

    return ""


# ---------------------------------------------------------------------------
# Brightspace identity
# ---------------------------------------------------------------------------

def make_brightspace_uid(event):

    uid = event.get("UID", "").strip()

    if not uid:
        return ""

    recurrence_id = event.get(
        "RECURRENCE-ID",
        "",
    ).strip()

    if recurrence_id:
        return f"{uid}|{recurrence_id}"

    return uid


# ---------------------------------------------------------------------------
# Date helpers
# ---------------------------------------------------------------------------

def parse_due_date(value, tzid=None):

    # All-day event.
    if len(value) == 8 and value.isdigit():

        dt = datetime.strptime(
            value,
            "%Y%m%d",
        )

        return dt.strftime(
            "%Y-%m-%d"
        )

    # UTC.
    if value.endswith("Z"):

        dt = datetime.strptime(
            value,
            "%Y%m%dT%H%M%SZ",
        )

        dt = dt.replace(
            tzinfo=timezone.utc,
        )

        dt = dt.astimezone()

        return dt.strftime(
            "%Y-%m-%dT%H:%M:%S"
        )

    # Explicit timezone.
    if tzid:

        try:

            dt = datetime.strptime(
                value,
                "%Y%m%dT%H%M%S",
            )

            dt = dt.replace(
                tzinfo=ZoneInfo(tzid),
            )

            dt = dt.astimezone()

            return dt.strftime(
                "%Y-%m-%dT%H:%M:%S"
            )

        except Exception:
            pass

    # Floating/local time.
    dt = datetime.strptime(
        value,
        "%Y%m%dT%H%M%S",
    )

    return dt.strftime(
        "%Y-%m-%dT%H:%M:%S"
    )


def parse_ics_instant(value, tzid=None):
    """
    Parse the ORIGINAL ICS DTSTART into an aware datetime.

    This is used for comparisons so that timezone and DST information
    is not lost.
    """

    # All-day event.
    if len(value) == 8 and value.isdigit():

        return datetime.strptime(
            value,
            "%Y%m%d",
        ).date()

    # Explicit UTC.
    if value.endswith("Z"):

        return datetime.strptime(
            value,
            "%Y%m%dT%H%M%SZ",
        ).replace(
            tzinfo=timezone.utc
        )

    # Explicit timezone.
    if tzid:

        dt = datetime.strptime(
            value,
            "%Y%m%dT%H%M%S",
        )

        return dt.replace(
            tzinfo=ZoneInfo(tzid)
        )

    # Floating/local time.
    #
    # time.mktime() applies the system timezone's DST rules for
    # the date being converted, rather than today's offset.
    dt = datetime.strptime(
        value,
        "%Y%m%dT%H%M%S",
    )

    timestamp = time.mktime(
        dt.timetuple()
    )

    return datetime.fromtimestamp(
        timestamp,
        timezone.utc,
    )


def parse_taskwarrior_due(value):
    """
    Parse Taskwarrior's exported date/time.

    Taskwarrior normally exports timed values as UTC, e.g.:

        20261110T100000Z
    """

    if not value:
        return None

    value = str(value)

    try:

        if value.endswith("Z"):

            return datetime.strptime(
                value,
                "%Y%m%dT%H%M%SZ",
            ).replace(
                tzinfo=timezone.utc
            )

        dt = datetime.fromisoformat(value)

        if dt.tzinfo is None:
            return None

        return dt

    except ValueError:
        return None


def due_dates_equal(existing_due, ics_value, tzid=None):
    """
    Compare Taskwarrior's stored due date against the ORIGINAL
    Brightspace DTSTART.

    This compares actual instants rather than string representations,
    avoiding DST-related false updates.
    """

    if not existing_due or not ics_value:
        return existing_due == ics_value

    existing_dt = parse_taskwarrior_due(
        existing_due
    )

    if existing_dt is None:
        return False

    # All-day event.
    if len(ics_value) == 8 and ics_value.isdigit():

        ics_date = datetime.strptime(
            ics_value,
            "%Y%m%d",
        ).date()

        return (
            existing_dt.astimezone().date()
            == ics_date
        )

    new_dt = parse_ics_instant(
        ics_value,
        tzid,
    )

    return (
        int(existing_dt.timestamp())
        == int(new_dt.timestamp())
    )


def is_future(value, tzid=None):
    """
    Determine whether an ORIGINAL ICS DTSTART is in the future.

    Uses the actual timezone/DST rules of the event.
    """

    now = datetime.now().astimezone()

    # All-day event.
    if len(value) == 8 and value.isdigit():

        due_date = datetime.strptime(
            value,
            "%Y%m%d",
        ).date()

        return due_date >= now.date()

    due_datetime = parse_ics_instant(
        value,
        tzid,
    )

    return due_datetime >= now


# ---------------------------------------------------------------------------
# Load existing tasks
# ---------------------------------------------------------------------------

with open(TASKS_FILE, "r", encoding="utf-8") as f:
    existing_tasks = json.load(f)


# ---------------------------------------------------------------------------
# Index existing Brightspace tasks
# ---------------------------------------------------------------------------

tasks_by_uid = {}

for task in existing_tasks:

    uid = str(
        task.get(UDA_UID, "")
    ).strip()

    if uid:
        tasks_by_uid[uid] = task


print(
    f"Found {len(existing_tasks)} existing "
    f"Taskwarrior tasks."
)

print(
    f"Found {len(tasks_by_uid)} "
    f"Brightspace-linked tasks."
)


# ---------------------------------------------------------------------------
# Process Brightspace events
# ---------------------------------------------------------------------------

events = parse_ics(ICS_FILE)

added = 0
updated = 0
skipped = 0


for event in events:

    summary = event.get(
        "SUMMARY",
        "",
    ).strip()

    location = event.get(
        "LOCATION",
        "",
    ).strip()

    start = event.get(
        "DTSTART",
        "",
    ).strip()

    tzid = event.get(
        "DTSTART_TZID",
    )

    # Only assignment due events.
    if "- Due" not in summary:
        continue

    # -----------------------------------------------------------------------
    # Brightspace UID
    # -----------------------------------------------------------------------

    brightspace_uid = make_brightspace_uid(
        event
    )

    if not brightspace_uid:

        print(
            f"SKIP: {summary} (no UID)"
        )

        skipped += 1
        continue

    # -----------------------------------------------------------------------
    # Due date
    # -----------------------------------------------------------------------

    if not start:

        print(
            f"SKIP: {summary} (no DTSTART)"
        )

        skipped += 1
        continue

    try:

        due = parse_due_date(
            start,
            tzid,
        )

    except Exception as error:

        print(
            f"SKIP: {summary}: {error}"
        )

        skipped += 1
        continue

    # -----------------------------------------------------------------------
    # Build visible Taskwarrior description.
    # -----------------------------------------------------------------------

    title = summary

    if title.endswith("- Due"):
        title = title[:-5].strip()

    if location:

        task_description = (
            f"{location} - {title}"
        )

    else:

        task_description = title

    # -----------------------------------------------------------------------
    # Brightspace description
    # -----------------------------------------------------------------------

    raw_description = event.get(
        "DESCRIPTION",
        "",
    ).strip()

    brightspace_description = normalize_description(
        raw_description
    )

    # -----------------------------------------------------------------------
    # Brightspace event URL
    # -----------------------------------------------------------------------

    brightspace_url = event.get(
        "URL",
        "",
    ).strip()

    if not brightspace_url:

        brightspace_url = extract_event_url(
            raw_description
        )

    # -----------------------------------------------------------------------
    # Assignment/materials URL
    # -----------------------------------------------------------------------

    brightspace_materials = extract_materials_url(
        raw_description
    )

    # -----------------------------------------------------------------------
    # Find existing task by UID.
    # -----------------------------------------------------------------------

    existing = tasks_by_uid.get(
        brightspace_uid
    )

    # -----------------------------------------------------------------------
    # Existing task → synchronize it.
    # -----------------------------------------------------------------------

    if existing is not None:

        modifications = {}

        # ---------------------------------------------------------------
        # Compare the ORIGINAL ICS DTSTART against Taskwarrior.
        #
        # This avoids false updates caused by DST / timezone formatting.
        # ---------------------------------------------------------------

        if not due_dates_equal(
            existing.get("due", ""),
            start,
            tzid,
        ):

            modifications["due"] = due

        # ---------------------------------------------------------------
        # Brightspace description changed.
        # ---------------------------------------------------------------

        if (
            existing.get(
                UDA_DESCRIPTION,
                "",
            )
            != brightspace_description
        ):

            modifications[
                UDA_DESCRIPTION
            ] = brightspace_description

        # ---------------------------------------------------------------
        # Event URL changed.
        # ---------------------------------------------------------------

        if (
            existing.get(
                UDA_URL,
                "",
            )
            != brightspace_url
        ):

            modifications[
                UDA_URL
            ] = brightspace_url

        # ---------------------------------------------------------------
        # Materials URL changed.
        # ---------------------------------------------------------------

        if (
            existing.get(
                UDA_MATERIALS,
                "",
            )
            != brightspace_materials
        ):

            modifications[
                UDA_MATERIALS
            ] = brightspace_materials

        # ---------------------------------------------------------------
        # UID should remain the same.
        # ---------------------------------------------------------------

        if (
            existing.get(
                UDA_UID,
                "",
            )
            != brightspace_uid
        ):

            modifications[
                UDA_UID
            ] = brightspace_uid

        # ---------------------------------------------------------------
        # Main visible task description changed.
        #
        # For example, the lecturer changes:
        #
        #     Huiswerk 4
        #
        # to:
        #
        #     Huiswerk 4 (revised)
        #
        # The existing task is updated rather than duplicated.
        # ---------------------------------------------------------------

        description_changed = (
            existing.get(
                "description",
                "",
            )
            != task_description
        )

        if modifications or description_changed:

            print(
                f"UPDATE: {task_description}"
            )

            if modify_task(
                existing,
                task_description,
                modifications,
            ):

                updated += 1

        else:

            print(
                f"EXISTS: {task_description}"
            )

        continue

    # -----------------------------------------------------------------------
    # No existing task.
    #
    # Don't create new tasks for past assignments.
    # -----------------------------------------------------------------------

    if not is_future(
        start,
        tzid,
    ):

        print(
            f"SKIP (past): {task_description}"
        )

        skipped += 1
        continue

    # -----------------------------------------------------------------------
    # Create new task.
    # -----------------------------------------------------------------------

    if add_task(
        description=task_description,
        due=due,
        brightspace_uid=brightspace_uid,
        brightspace_description=brightspace_description,
        brightspace_url=brightspace_url,
        brightspace_materials=brightspace_materials,
    ):

        print(
            f"ADDED: {task_description}"
        )

        added += 1

        # Protect against duplicate events inside the same ICS.
        tasks_by_uid[brightspace_uid] = {
            "uuid": "",
            UDA_UID: brightspace_uid,
            "description": task_description,
            "due": due,
        }


# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

print()
print("Finished:")
print(f"  {added} added")
print(f"  {updated} updated")
print(f"  {skipped} skipped")
