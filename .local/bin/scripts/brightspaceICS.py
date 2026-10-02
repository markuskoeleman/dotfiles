#!/usr/bin/env python3

import sys
import json
import re
import subprocess
from datetime import datetime, timezone
from zoneinfo import ZoneInfo


ICS_FILE = sys.argv[1]
TASKS_FILE = sys.argv[2]
PROJECT = sys.argv[3]


# ---------------------------------------------------------------------------
# Taskwarrior / Brightspace UDA names
# ---------------------------------------------------------------------------

UDA_UID = "brightspace.uid"
UDA_DESCRIPTION = "brightspace.description"
UDA_URL = "brightspace.url"
UDA_MATERIALS = "brightspace.materials"


# ---------------------------------------------------------------------------
# ICS helpers
# ---------------------------------------------------------------------------

def unfold(lines):
    """
    Unfold RFC 5545 continuation lines.

    A line beginning with a space or tab continues the previous line.
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

        # Store useful event fields.
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

        # DTSTART timezone.
        if field_name == "DTSTART":

            for parameter in field.split(";")[1:]:

                if parameter.upper().startswith("TZID="):
                    event["DTSTART_TZID"] = parameter[5:].strip('"')

        # RECURRENCE-ID timezone.
        if field_name == "RECURRENCE-ID":

            for parameter in field.split(";")[1:]:

                if parameter.upper().startswith("TZID="):
                    event["RECURRENCE_ID_TZID"] = parameter[5:].strip('"')

    return events


# ---------------------------------------------------------------------------
# Brightspace helpers
# ---------------------------------------------------------------------------

def normalize_text(value):
    """
    Normalize whitespace without destroying meaningful newlines.
    """
    if not value:
        return ""

    lines = []

    for line in value.splitlines():

        line = line.strip()

        if line:
            lines.append(line)

    return "\n".join(lines)


def extract_urls(text):
    """
    Extract HTTP(S) URLs from an ICS description.
    """
    if not text:
        return []

    return re.findall(
        r"https?://[^\s<>]+",
        text
    )


def clean_url(url):
    """
    Remove punctuation that is commonly attached to URLs in text.
    """
    if not url:
        return ""

    return url.rstrip(".,);]>")


def extract_materials_url(description):
    """
    Try to find the URL associated with 'Materials'.
    """

    if not description:
        return ""

    lines = description.splitlines()

    for i, line in enumerate(lines):

        if line.lower().startswith("materials"):

            # URL on same line.
            urls = extract_urls(line)

            if urls:
                return clean_url(urls[0])

            # Or URL on the following line(s).
            for following in lines[i + 1: i + 3]:

                urls = extract_urls(following)

                if urls:
                    return clean_url(urls[0])

    return ""


def extract_event_url(description):
    """
    Try to find the Brightspace calendar event URL.

    Brightspace currently appears to put this in the DESCRIPTION as
    something like:

        View event - https://...
    """

    if not description:
        return ""

    for line in description.splitlines():

        if "view event" in line.lower():

            urls = extract_urls(line)

            if urls:
                return clean_url(urls[0])

    return ""


def make_brightspace_uid(event):
    """
    UID is the primary identity.

    For a recurring VEVENT, UID alone identifies the recurrence set.
    RECURRENCE-ID identifies an individual occurrence.

    Therefore:

        UID

    becomes:

        UID|RECURRENCE-ID

    when RECURRENCE-ID exists.
    """

    uid = event.get("UID", "").strip()

    if not uid:
        return ""

    recurrence_id = event.get(
        "RECURRENCE-ID",
        ""
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
            "%Y%m%d"
        )

        return dt.strftime("%Y-%m-%d")

    # UTC.
    if value.endswith("Z"):

        dt = datetime.strptime(
            value,
            "%Y%m%dT%H%M%SZ"
        )

        dt = dt.replace(
            tzinfo=timezone.utc
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
                "%Y%m%dT%H%M%S"
            )

            dt = dt.replace(
                tzinfo=ZoneInfo(tzid)
            )

            dt = dt.astimezone()

            return dt.strftime(
                "%Y-%m-%dT%H:%M:%S"
            )

        except Exception:
            pass

    # Local/floating time.
    dt = datetime.strptime(
        value,
        "%Y%m%dT%H%M%S"
    )

    return dt.strftime(
        "%Y-%m-%dT%H:%M:%S"
    )


def is_future(due):

    now = datetime.now().astimezone()

    # All-day event.
    if len(due) == 10:

        due_date = datetime.strptime(
            due,
            "%Y-%m-%d"
        ).date()

        return due_date >= now.date()

    # Date-time event.
    due_datetime = datetime.strptime(
        due,
        "%Y-%m-%dT%H:%M:%S"
    )

    due_datetime = due_datetime.replace(
        tzinfo=now.tzinfo
    )

    return due_datetime >= now


# ---------------------------------------------------------------------------
# Taskwarrior helpers
# ---------------------------------------------------------------------------

def run_task(*args):

    """
    Run Taskwarrior.

    Returns CompletedProcess.
    """

    return subprocess.run(
        [
            "task",
            *args,
        ],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def task_identifier(task):
    """
    Prefer UUID because numeric Taskwarrior IDs can change depending
    on the current task database/report.
    """

    return task.get("uuid") or str(
        task.get("id", "")
    )


def modify_task(task, modifications):

    """
    Modify an existing task by UUID.

    modifications is a dictionary:

        {
            "due": "...",
            "brightspace.uid": "...",
            ...
        }

    Empty values are explicitly cleared.
    """

    identifier = task_identifier(task)

    if not identifier:
        return False

    args = [
        identifier,
        "modify",
    ]

    for key, value in modifications.items():

        if value == "":
            args.append(f"{key}:")

        else:
            args.append(
                f"{key}:{value}"
            )

    result = run_task(*args)

    if result.returncode != 0:

        print(
            f"ERROR modifying task {identifier}: "
            f"{result.stderr.strip()}",
            file=sys.stderr,
        )

        return False

    return True


def add_task(
    description,
    due,
    uid,
    event_description,
    event_url,
    materials_url,
):

    args = [
        "add",
        description,
        f"due:{due}",
        f"project:{PROJECT}",
        f"{UDA_UID}:{uid}",
    ]

    if event_description:
        args.append(
            f"{UDA_DESCRIPTION}:{event_description}"
        )

    if event_url:
        args.append(
            f"{UDA_URL}:{event_url}"
        )

    if materials_url:
        args.append(
            f"{UDA_MATERIALS}:{materials_url}"
        )

    result = run_task(*args)

    if result.returncode != 0:

        print(
            f"ERROR adding {description}: "
            f"{result.stderr.strip()}",
            file=sys.stderr,
        )

        return None

    # task add normally outputs:
    #
    # Created task 123.
    #
    # We don't actually need the ID because the UDA is already
    # attached during creation.

    return result


# ---------------------------------------------------------------------------
# Load existing Taskwarrior tasks
# ---------------------------------------------------------------------------

with open(TASKS_FILE, "r", encoding="utf-8") as f:
    existing_tasks = json.load(f)


# ---------------------------------------------------------------------------
# Build indexes
# ---------------------------------------------------------------------------

# Primary index:
#
#     Brightspace UID -> Task
#
tasks_by_brightspace_uid = {}

# Legacy fallback:
#
# Existing tasks created by your OLD script don't have a
# brightspace.uid yet. We can still recognize them by description
# once, then migrate them to UID-based identification.
tasks_by_description = {}


for task in existing_tasks:

    uid = task.get(UDA_UID, "").strip()

    if uid:
        tasks_by_brightspace_uid[uid] = task

    task_description = task.get(
        "description",
        ""
    ).strip()

    if task_description:
        tasks_by_description[
            task_description
        ] = task


print(
    f"Found {len(existing_tasks)} existing Taskwarrior tasks."
)

print(
    f"Found {len(tasks_by_brightspace_uid)} "
    f"Brightspace-linked tasks."
)


# ---------------------------------------------------------------------------
# Process Brightspace
# ---------------------------------------------------------------------------

events = parse_ics(ICS_FILE)

added = 0
updated = 0
migrated = 0
skipped = 0


for event in events:

    summary = event.get(
        "SUMMARY",
        ""
    ).strip()

    location = event.get(
        "LOCATION",
        ""
    ).strip()

    start = event.get(
        "DTSTART",
        ""
    ).strip()

    tzid = event.get(
        "DTSTART_TZID"
    )

    # -----------------------------------------------------------------------
    # Only assignments/events containing "- Due".
    # -----------------------------------------------------------------------

    if "- Due" not in summary:
        continue

    # -----------------------------------------------------------------------
    # UID
    # -----------------------------------------------------------------------

    brightspace_uid = make_brightspace_uid(event)

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
            f"SKIP: {summary} (no due date)"
        )

        skipped += 1
        continue

    try:

        due = parse_due_date(
            start,
            tzid
        )

    except Exception as e:

        print(
            f"SKIP: {summary}: {e}"
        )

        skipped += 1
        continue

    # -----------------------------------------------------------------------
    # Only future assignments.
    # -----------------------------------------------------------------------

    if not is_future(due):

        print(
            f"SKIP (past): {summary}"
        )

        skipped += 1
        continue

    # -----------------------------------------------------------------------
    # Clean assignment title.
    # -----------------------------------------------------------------------

    title = summary

    if title.endswith("- Due"):
        title = title[:-5].strip()

    # -----------------------------------------------------------------------
    # Task description.
    #
    # Keep this deliberately clean because this is what you see
    # in your normal Taskwarrior/Vit list.
    # -----------------------------------------------------------------------

    if location:
        description = f"{location} - {title}"
    else:
        description = title

    # -----------------------------------------------------------------------
    # Brightspace description.
    # -----------------------------------------------------------------------

    event_description = normalize_text(
        event.get(
            "DESCRIPTION",
            ""
        )
    )

    # -----------------------------------------------------------------------
    # URLs.
    # -----------------------------------------------------------------------

    event_url = clean_url(
        event.get(
            "URL",
            ""
        ).strip()
    )

    if not event_url:
        event_url = extract_event_url(
            event_description
        )

    materials_url = extract_materials_url(
        event_description
    )

    # -----------------------------------------------------------------------
    # Look for existing task by UID.
    # -----------------------------------------------------------------------

    existing = tasks_by_brightspace_uid.get(
        brightspace_uid
    )

    # -----------------------------------------------------------------------
    # Legacy migration.
    #
    # Tasks created by your OLD script don't have brightspace.uid.
    #
    # If the generated description matches an old task exactly,
    # attach all the new Brightspace metadata to that task instead
    # of creating a duplicate.
    # -----------------------------------------------------------------------

    if existing is None:

        legacy = tasks_by_description.get(
            description
        )

        if legacy is not None:

            existing = legacy

            print(
                f"MIGRATE: {description}"
            )

            modifications = {
                UDA_UID: brightspace_uid,
                UDA_DESCRIPTION: event_description,
                UDA_URL: event_url,
                UDA_MATERIALS: materials_url,
            }

            # Update due as well, because Brightspace is now the
            # authoritative source for the assignment deadline.
            modifications["due"] = due

            if modify_task(
                existing,
                modifications
            ):
                tasks_by_brightspace_uid[
                    brightspace_uid
                ] = existing

                migrated += 1

            continue

    # -----------------------------------------------------------------------
    # Existing Brightspace task.
    # -----------------------------------------------------------------------

    if existing is not None:

        print(
            f"EXISTS: {description}"
        )

        modifications = {}

        # Update the deadline if Brightspace changed it.
        if existing.get("due", "") != due:
            modifications["due"] = due

        # Update the Brightspace description if it changed.
        if existing.get(
            UDA_DESCRIPTION,
            ""
        ) != event_description:

            modifications[
                UDA_DESCRIPTION
            ] = event_description

        # Update event URL.
        if existing.get(
            UDA_URL,
            ""
        ) != event_url:

            modifications[
                UDA_URL
            ] = event_url

        # Update materials URL.
        if existing.get(
            UDA_MATERIALS,
            ""
        ) != materials_url:

            modifications[
                UDA_MATERIALS
            ] = materials_url

        # The UID itself should never normally change.
        if existing.get(
            UDA_UID,
            ""
        ) != brightspace_uid:

            modifications[
                UDA_UID
            ] = brightspace_uid

        if modifications:

            if modify_task(
                existing,
                modifications
            ):

                print(
                    f"UPDATED: {description}"
                )

                updated += 1

        continue

    # -----------------------------------------------------------------------
    # New task.
    # -----------------------------------------------------------------------

    result = add_task(
        description=description,
        due=due,
        uid=brightspace_uid,
        event_description=event_description,
        event_url=event_url,
        materials_url=materials_url,
    )

    if result is None:
        continue

    print(
        f"ADDED:   {description}"
    )

    added += 1

    # Protect against duplicate events in the same ICS.
    #
    # We don't have to know the Taskwarrior ID here because the UID
    # itself is enough for this run.
    tasks_by_brightspace_uid[
        brightspace_uid
    ] = {
        UDA_UID: brightspace_uid,
        "description": description,
        "due": due,
    }


# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

print()
print(
    "Finished:"
)

print(
    f"  {added} added"
)

print(
    f"  {updated} updated"
)

print(
    f"  {migrated} migrated from old format"
)

print(
    f"  {skipped} skipped"
)
