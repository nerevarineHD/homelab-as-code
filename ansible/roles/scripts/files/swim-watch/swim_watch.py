#!/usr/bin/env python3
"""
Seattle Parks (ActiveNet) swim-lesson watcher.

Polls the same JSON endpoint the activity-search page uses and pushes a
notification when a listing shows up that it hasn't seen before.
Stdlib only -- no pip installs needed.

First run seeds the "seen" list silently (so today's Fall classes don't
spam you), then every later run alerts only on new activity IDs.

Config is via env vars (or edit the defaults below):
  SITE_IDS          ActiveNet site IDs to search, comma-separated; empty = all locations
  NTFY_TOPIC        ntfy.sh topic to push to (pick something unguessable)
  NTFY_SERVER       default https://ntfy.sh
  DISCORD_WEBHOOK   Discord webhook URL, alerts go here too
  DISCORD_USERNAME  name the posts show under, default "Swim Watch"
  DISCORD_MENTION   prepended to new-listing alerts only, e.g. <@your_user_id> or @here
  STATE_FILE        default ./swim_watch_state.json
  MAX_JITTER_SEC    random sleep before polling, default 90
  FAIL_ALERT_AFTER  consecutive failures before a "watcher broken" alert, default 3
  KUMA_PUSH_URL     optional Uptime Kuma push URL (no ?status part); pinged after every good run,
                    so Kuma alerts if the runs stop (CT down, timer broken), not just the site
"""

import json
import os
import random
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime

# ---- Search filters (mirrors the activity-search page's filters) -----------
# SITE_IDS: comma-separated ActiveNet site IDs (the site_ids= value in a search URL);
# empty = every location. Kept out of the code on purpose.
SITE_IDS = [s.strip() for s in os.environ.get("SITE_IDS", "").split(",") if s.strip()]
SEARCH = {
    "activity_keyword": "Learn to swim",
    "site_ids": SITE_IDS,
    "time_after_str": "17:00:00",  # must be HH:MM:SS or the filter is ignored
    "days_of_week": "0000000",     # 0000000 = any day
    "max_age": 1,
    "min_age": None,
}
# Only alert on names containing this (case-insensitive). "" to disable.
NAME_MUST_CONTAIN = "parent and child"

# ---- Settings --------------------------------------------------------------
URL = "https://anc.apm.activecommunities.com/seattle/rest/activities/list?locale=en-US"
SEARCH_PAGE = (
    "https://anc.apm.activecommunities.com/seattle/activity/search?onlineSiteId=0"
    "&time_after_str=17%3A00&days_of_week=0000000"
    + (f"&site_ids={','.join(SITE_IDS)}" if SITE_IDS else "")
    + "&activity_keyword=Learn%20to%20swim&max_age=1&viewMode=list"
)
NTFY_SERVER = os.environ.get("NTFY_SERVER", "https://ntfy.sh").rstrip("/")
NTFY_TOPIC = os.environ.get("NTFY_TOPIC", "")
DISCORD_WEBHOOK = os.environ.get("DISCORD_WEBHOOK", "")
DISCORD_USERNAME = os.environ.get("DISCORD_USERNAME", "Swim Watch")
DISCORD_MENTION = os.environ.get("DISCORD_MENTION", "")  # e.g. <@123456789012345678> or @here
STATE_FILE = os.environ.get(
    "STATE_FILE", os.path.join(os.path.dirname(os.path.abspath(__file__)), "swim_watch_state.json")
)
MAX_JITTER_SEC = int(os.environ.get("MAX_JITTER_SEC", "90"))
FAIL_ALERT_AFTER = int(os.environ.get("FAIL_ALERT_AFTER", "3"))
KUMA_PUSH_URL = os.environ.get("KUMA_PUSH_URL", "")
UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"


def log(msg):
    print(f"{datetime.now():%Y-%m-%d %H:%M:%S} {msg}", flush=True)


def build_body():
    p = {
        "skills": [], "time_after_str": "", "days_of_week": "0000000",
        "activity_select_param": None, "center_ids": [], "time_before_str": "",
        "open_spots": None, "activity_id": None, "activity_category_ids": [],
        "date_before": "", "min_age": None, "date_after": "", "activity_type_ids": [],
        "site_ids": [], "for_map": False, "geographic_area_ids": [], "season_ids": [],
        "activity_department_ids": [], "activity_other_category_ids": [],
        "child_season_ids": [], "activity_keyword": "", "instructor_ids": [],
        "max_age": None, "is_drop_in": False, "family_member_ids": [],
        "custom_price_from": "", "custom_price_to": "",
    }
    p.update(SEARCH)
    return {"activity_search_pattern": p, "activity_transfer_pattern": {}}


def fetch_all():
    items, page = [], 1
    while True:
        req = urllib.request.Request(
            URL,
            data=json.dumps(build_body()).encode(),
            method="POST",
            headers={
                "Content-Type": "application/json;charset=utf-8",
                "X-Requested-With": "XMLHttpRequest",
                "User-Agent": UA,
                "page_info": json.dumps(
                    {"order_by": "Name", "page_number": page, "total_records_per_page": 50}
                ),
            },
        )
        with urllib.request.urlopen(req, timeout=30) as r:
            data = json.load(r)
        hdr = data.get("headers", {})
        if hdr.get("response_code") != "0000":
            raise RuntimeError(f"API error {hdr.get('response_code')}: {hdr.get('response_message')}")
        items += data["body"].get("activity_items") or []
        info = hdr.get("page_info") or {}
        if page >= int(info.get("total_page") or 1):
            return items
        page += 1


def notify(title, message, url=None, priority="high"):
    if NTFY_TOPIC:
        headers = {"Title": title, "Priority": priority, "Tags": "swimmer"}
        if url:
            headers["Click"] = url
        req = urllib.request.Request(
            f"{NTFY_SERVER}/{NTFY_TOPIC}", data=message.encode(), headers=headers, method="POST"
        )
        urllib.request.urlopen(req, timeout=15).read()
    if DISCORD_WEBHOOK:
        content = f"**{title}**\n{message}" + (f"\n<{url}>" if url else "")
        if priority == "urgent" and DISCORD_MENTION:
            content = f"{DISCORD_MENTION} {content}"
        payload = {
            "username": DISCORD_USERNAME,
            "content": content[:1900],
            "allowed_mentions": {"parse": ["users", "roles", "everyone"]},
        }
        req = urllib.request.Request(
            DISCORD_WEBHOOK,
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json", "User-Agent": UA},
            method="POST",
        )
        urllib.request.urlopen(req, timeout=15).read()
    if not (NTFY_TOPIC or DISCORD_WEBHOOK):
        log(f"[no notifier configured] {title}: {message}")


def describe(a):
    status = (a.get("urgent_message") or {}).get("status_description") or ""
    reg = a.get("activity_online_start_time") or ""
    lines = [
        f"#{a.get('number')} {a.get('name')}",
        f"{a.get('days_of_week')} {a.get('time_range')} | {a.get('date_range')}",
        f"{(a.get('location') or {}).get('label', '')} | openings: {a.get('openings')} {status}".strip(),
    ]
    if reg:
        lines.append(f"Online reg opens: {reg}")
    return "\n".join(lines)


def kuma_push(msg):
    if not KUMA_PUSH_URL:
        return
    try:
        q = urllib.parse.urlencode({"status": "up", "msg": msg, "ping": ""})
        urllib.request.urlopen(f"{KUMA_PUSH_URL}?{q}", timeout=10).read()
    except Exception as e:  # a Kuma hiccup must never fail the run
        log(f"Kuma push failed: {e}")


def load_state():
    try:
        with open(STATE_FILE) as f:
            return json.load(f)
    except FileNotFoundError:
        return None


def save_state(state):
    tmp = STATE_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f, indent=2)
    os.replace(tmp, STATE_FILE)


def main():
    if "--no-jitter" not in sys.argv and MAX_JITTER_SEC > 0:
        time.sleep(random.uniform(0, MAX_JITTER_SEC))

    state = load_state()
    first_run = state is None
    state = state or {"seen": {}, "failures": 0, "fail_alerted": False}

    if "--test-notify" in sys.argv:
        notify("Swim watcher test", "If you got this, notifications work.", SEARCH_PAGE, "default")
        return

    try:
        items = fetch_all()
    except Exception as e:
        state["failures"] += 1
        log(f"fetch failed ({state['failures']}x): {e}")
        if state["failures"] >= FAIL_ALERT_AFTER and not state["fail_alerted"]:
            notify("Swim watcher is failing",
                   f"{state['failures']} failures in a row. Last error: {e}", SEARCH_PAGE, "default")
            state["fail_alerted"] = True
        save_state(state)
        sys.exit(1)

    if state["fail_alerted"]:
        notify("Swim watcher recovered", "Polling is working again.", None, "low")
    state["failures"], state["fail_alerted"] = 0, False

    if NAME_MUST_CONTAIN:
        items = [a for a in items if NAME_MUST_CONTAIN in (a.get("name") or "").lower()]

    new = [a for a in items if str(a["id"]) not in state["seen"]]
    for a in items:
        state["seen"].setdefault(str(a["id"]), {
            "number": a.get("number"), "date_range": a.get("date_range"),
            "first_seen": datetime.now().isoformat(timespec="seconds"),
        })

    if first_run:
        log(f"first run: seeded {len(items)} existing listing(s), no alerts sent")
    elif new:
        log(f"{len(new)} new listing(s)")
        body = "\n\n".join(describe(a) for a in new)
        notify(f"{len(new)} new swim class listing(s)!", body, SEARCH_PAGE, "urgent")
    else:
        log(f"no new listings ({len(items)} total)")

    save_state(state)
    kuma_push(f"OK, {len(items)} listing(s)")


if __name__ == "__main__":
    main()
