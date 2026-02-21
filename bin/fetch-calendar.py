#!/usr/bin/env python3
"""Fetch today's Google Calendar events using OAuth tokens from ~/.clasprc.json.

Outputs JSON array of events to stdout.
Uses only standard library (urllib + json). Handles token refresh automatically.
Returns empty array [] on any failure (graceful fallback).
"""

import json
import os
import sys
import urllib.request
import urllib.parse
import urllib.error
from datetime import datetime, timezone, timedelta

CLASPRC_PATH = os.path.expanduser("~/.clasprc.json")
TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token"
CALENDAR_API = "https://www.googleapis.com/calendar/v3"

JST = timezone(timedelta(hours=9))


def load_tokens():
    with open(CLASPRC_PATH) as f:
        data = json.load(f)
    t = data["tokens"]["default"]
    return {
        "access_token": t["access_token"],
        "refresh_token": t["refresh_token"],
        "client_id": t["client_id"],
        "client_secret": t["client_secret"],
    }


def refresh_access_token(tokens):
    body = urllib.parse.urlencode({
        "client_id": tokens["client_id"],
        "client_secret": tokens["client_secret"],
        "refresh_token": tokens["refresh_token"],
        "grant_type": "refresh_token",
    }).encode()
    req = urllib.request.Request(TOKEN_ENDPOINT, data=body, method="POST")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")
    with urllib.request.urlopen(req, timeout=10) as resp:
        result = json.loads(resp.read())
    new_access = result["access_token"]

    # Persist refreshed token back to clasprc.json
    with open(CLASPRC_PATH) as f:
        data = json.load(f)
    data["tokens"]["default"]["access_token"] = new_access
    if "id_token" in data["tokens"]["default"]:
        data["tokens"]["default"]["id_token"] = new_access
    with open(CLASPRC_PATH, "w") as f:
        json.dump(data, f, indent=2)

    return new_access


def fetch_events(access_token, date_str):
    """Fetch calendar events for a given date (YYYY-MM-DD) in JST."""
    time_min = f"{date_str}T00:00:00+09:00"
    time_max = f"{date_str}T23:59:59+09:00"
    params = urllib.parse.urlencode({
        "timeMin": time_min,
        "timeMax": time_max,
        "singleEvents": "true",
        "orderBy": "startTime",
        "maxResults": 50,
    })
    url = f"{CALENDAR_API}/calendars/primary/events?{params}"
    req = urllib.request.Request(url)
    req.add_header("Authorization", f"Bearer {access_token}")
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read())


def format_events(raw):
    """Extract relevant fields from calendar API response."""
    events = []
    for item in raw.get("items", []):
        start = item.get("start", {})
        end = item.get("end", {})
        events.append({
            "summary": item.get("summary", "(no title)"),
            "start": start.get("dateTime", start.get("date", "")),
            "end": end.get("dateTime", end.get("date", "")),
            "location": item.get("location", ""),
            "attendees": len(item.get("attendees", [])),
            "status": item.get("status", ""),
        })
    return events


def main():
    # Target date: today in JST (or pass YYYY-MM-DD as argument)
    if len(sys.argv) > 1:
        target_date = sys.argv[1]
    else:
        target_date = datetime.now(JST).strftime("%Y-%m-%d")

    tokens = load_tokens()

    # Try with current access token first, refresh if 401
    for attempt in range(2):
        try:
            raw = fetch_events(tokens["access_token"], target_date)
            print(json.dumps(format_events(raw), ensure_ascii=False, indent=2))
            return
        except urllib.error.HTTPError as e:
            if e.code == 401 and attempt == 0:
                tokens["access_token"] = refresh_access_token(tokens)
            elif e.code == 403:
                # Calendar API not enabled or no permission
                print("[]")
                return
            else:
                raise


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        # Graceful fallback: print empty array on any error
        print(json.dumps([], ensure_ascii=False))
        print(f"# Calendar fetch error: {e}", file=sys.stderr)
