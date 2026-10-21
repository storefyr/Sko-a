# harbour-skodja - GitHub Activity Notifier for Sailfish OS
# Copyright (C) 2026 storefyr
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

import fcntl
import json
import os
import re
import subprocess
import time
import urllib.request
import urllib.error
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

GITHUB_API_BASE = "https://api.github.com"
GITHUB_ATOM_BASE = "https://github.com"
USER_AGENT = "harbour-skodja/0.1 (Sailfish OS)"


def _get_data_dir():
    xdg_data = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
    return os.path.join(xdg_data, "com.storefyr", "harbour-skodja")


DATA_DIR = _get_data_dir()
STATE_FILE = os.path.join(DATA_DIR, "state.json")
LOCK_FILE = os.path.join(DATA_DIR, "state.lock")
MAX_EVENTS_STORED = 500
MAX_NOTIFIED_STORED = 500
ATOM_NS = {"atom": "http://www.w3.org/2005/Atom"}


def ensure_data_dir():
    os.makedirs(DATA_DIR, exist_ok=True)


def acquire_lock(timeout=10):
    ensure_data_dir()
    lock_fd = os.open(LOCK_FILE, os.O_CREAT | os.O_RDWR, 0o644)
    start = time.time()
    while time.time() - start < timeout:
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return lock_fd
        except IOError:
            time.sleep(0.1)
    os.close(lock_fd)
    return None


def release_lock(lock_fd):
    if lock_fd is not None:
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
            os.close(lock_fd)
        except Exception:
            pass


def _is_old_release_id(event_id):
    """Check if an event ID uses the old (pre-0.6.4) release format.
    New format: release-{owner}/{repo}/{tag_name} (contains slashes after release-)
    Old API format: release-{numeric_id} (no slashes)
    Old Atom format: tag-... (starts with tag-)
    """
    if not event_id or not isinstance(event_id, str):
        return False
    if event_id.startswith("release-"):
        rest = event_id[len("release-") :]
        return "/" not in rest
    if event_id.startswith("tag-"):
        return True
    return False


def _migrate_old_release_ids(state):
    """Remove old-format release IDs from seen/notified lists.
    Old IDs won't match new normalized IDs, causing duplicate notifications.
    Removing them means old releases get re-notified once after upgrade,
    then stay stable with the new ID format.
    """
    seen = state.get("seen_events", [])
    notified = state.get("notified_events", [])
    new_seen = [e for e in seen if not _is_old_release_id(e)]
    new_notified = [e for e in notified if not _is_old_release_id(e)]
    if len(new_seen) != len(seen) or len(new_notified) != len(notified):
        state["seen_events"] = new_seen
        state["notified_events"] = new_notified
        return True
    return False


def load_state():
    ensure_data_dir()
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r") as f:
                state = json.load(f)
            if "notified_events" not in state:
                state["notified_events"] = []
            if _migrate_old_release_ids(state):
                save_state(state)
            return state
        except (json.JSONDecodeError, IOError):
            pass
    return {
        "last_check": None,
        "seen_events": [],
        "notified_events": [],
        "watched_users": ["storefyr"],
        "notifications_enabled": True,
        "notification_sound": True,
        "notification_filter": [
            "PushEvent",
            "PullRequestEvent",
            "IssuesEvent",
            "ReleaseEvent",
            "CreateEvent",
            "DeleteEvent",
            "WatchEvent",
            "ForkEvent",
            "CommitCommentEvent",
        ],
    }


def save_state(state):
    ensure_data_dir()
    state["seen_events"] = state["seen_events"][-MAX_EVENTS_STORED:]
    state["notified_events"] = state["notified_events"][-MAX_EVENTS_STORED:]
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


class RateLimitError(Exception):
    pass


def api_get(url):
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "application/vnd.github.v3+json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = ""
        try:
            body = e.read().decode("utf-8", errors="ignore").lower()
        except Exception:
            pass
        if e.code == 403 and "rate limit" in body:
            raise RateLimitError("GitHub API rate limit exceeded")
        raise


def fetch_atom_feed(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read().decode("utf-8")


def parse_atom_entries(xml_text):
    root = ET.fromstring(xml_text)
    entries = []
    for entry in root.findall("atom:entry", ATOM_NS):
        eid = entry.find("atom:id", ATOM_NS)
        title = entry.find("atom:title", ATOM_NS)
        updated = entry.find("atom:updated", ATOM_NS)
        published = entry.find("atom:published", ATOM_NS)
        link = entry.find("atom:link", ATOM_NS)
        author = entry.find("atom:author/atom:name", ATOM_NS)
        content = entry.find("atom:content", ATOM_NS)

        link_href = ""
        if link is not None:
            link_href = link.get("href", "")

        content_html = ""
        if content is not None and content.text:
            content_html = content.text

        entries.append(
            {
                "id": eid.text if eid is not None else "",
                "title": title.text if title is not None else "",
                "updated": updated.text if updated is not None else "",
                "published": published.text if published is not None else "",
                "url": link_href,
                "author": author.text if author is not None else "",
                "content": content_html,
            }
        )
    return entries


def parse_atom_title_to_event(title_text, username, content_html="", entry_id=""):
    title_text = title_text.strip()

    repo_from_link = ""
    repo_match = re.search(r"github\.com/([^/]+/[^/]+)", content_html)
    if repo_match:
        repo_from_link = repo_match.group(1)

    pushed_match = re.match(r"^(\S+) pushed (.+)$", title_text)
    if pushed_match:
        pushed_to = pushed_match.group(2)
        branch_match = re.search(r"@([^@]+)$", pushed_to)
        branch = branch_match.group(1) if branch_match else pushed_to
        repo_name = pushed_to.split("@")[0] if "@" in pushed_to else pushed_to
        commit_match = re.search(r"(\d+) new commit", content_html)
        commit_count = commit_match.group(1) if commit_match else ""
        body = f"{commit_count} commits" if commit_count else "Nye commits"
        return {
            "type": "PushEvent",
            "summary": f"Push til {branch}",
            "body": body,
            "repo": repo_from_link or f"{username}/{repo_name}",
        }

    created_branch_match = re.match(r"^(\S+) created a branch$", title_text)
    if created_branch_match:
        branch_match = re.search(r"in ([^ ]+):([^ ]+)$", content_html)
        if branch_match:
            repo = branch_match.group(1)
            branch = branch_match.group(2)
        else:
            repo = repo_from_link or username
            branch = "?"
        return {
            "type": "CreateEvent",
            "summary": "Ny branch",
            "body": branch,
            "repo": repo,
        }

    created_repo_match = re.match(r"^(\S+) created a repository$", title_text)
    if created_repo_match:
        repo = repo_from_link or username
        return {
            "type": "CreateEvent",
            "summary": "Nyt repository",
            "body": repo.split("/")[-1] if "/" in repo else repo,
            "repo": repo,
        }

    pr_opened_match = re.match(r"^(\S+) opened a pull request in (.+)$", title_text)
    if pr_opened_match:
        repo_name = pr_opened_match.group(2)
        pr_match = re.search(r"/pull/(\d+)", content_html)
        pr_num = pr_match.group(1) if pr_match else "?"
        return {
            "type": "PullRequestEvent",
            "summary": "Åbnede pull request",
            "body": f"#{pr_num} i {repo_name}",
            "repo": repo_from_link or f"{username}/{repo_name}",
        }

    pr_closed_match = re.match(r"^(\S+) closed a pull request in (.+)$", title_text)
    if pr_closed_match:
        repo_name = pr_closed_match.group(2)
        return {
            "type": "PullRequestEvent",
            "summary": "Lukkede pull request",
            "body": f"i {repo_name}",
            "repo": repo_from_link or f"{username}/{repo_name}",
        }

    issue_opened_match = re.match(r"^(\S+) opened an issue in (.+)$", title_text)
    if issue_opened_match:
        repo_name = issue_opened_match.group(2)
        issue_match = re.search(r"/issues/(\d+)", content_html)
        issue_num = issue_match.group(1) if issue_match else "?"
        return {
            "type": "IssuesEvent",
            "summary": "Åbnede issue",
            "body": f"#{issue_num} i {repo_name}",
            "repo": repo_from_link or f"{username}/{repo_name}",
        }

    issue_closed_match = re.match(r"^(\S+) closed an issue in (.+)$", title_text)
    if issue_closed_match:
        repo_name = issue_closed_match.group(2)
        return {
            "type": "IssuesEvent",
            "summary": "Lukkede issue",
            "body": f"i {repo_name}",
            "repo": repo_from_link or f"{username}/{repo_name}",
        }

    release_match = re.match(r"^(\S+) (published|created) a release in (.+)$", title_text)
    if release_match:
        repo_name = release_match.group(3)
        return {
            "type": "ReleaseEvent",
            "summary": "Ny release",
            "body": f"i {repo_name}",
            "repo": repo_from_link or f"{username}/{repo_name}",
        }

    star_match = re.match(r"^(\S+) starred (.+)$", title_text)
    if star_match:
        return {
            "type": "WatchEvent",
            "summary": "Starred repository",
            "body": star_match.group(2),
            "repo": star_match.group(2),
        }

    fork_match = re.match(r"^(\S+) forked (.+)$", title_text)
    if fork_match:
        return {
            "type": "ForkEvent",
            "summary": "Forked repository",
            "body": fork_match.group(2),
            "repo": fork_match.group(2),
        }

    comment_match = re.match(r"^(\S+) commented on (.+)$", title_text)
    if comment_match:
        return {
            "type": "CommitCommentEvent",
            "summary": "Ny kommentar",
            "body": comment_match.group(2),
            "repo": repo_from_link or username,
        }

    deleted_match = re.match(r"^(\S+) deleted (.+)$", title_text)
    if deleted_match:
        deleted_what = deleted_match.group(2)
        repo = repo_from_link or username
        return {
            "type": "DeleteEvent",
            "summary": "Slettede",
            "body": deleted_what.split("@")[0] if "@" in deleted_what else deleted_what,
            "repo": repo,
        }

    return {
        "type": "Activity",
        "summary": title_text.replace(username + " ", "").strip()[:40],
        "body": repo_from_link or username,
        "repo": repo_from_link or username,
    }


def fetch_user_events_api(username, per_page=30):
    url = f"{GITHUB_API_BASE}/users/{username}/events/public?per_page={per_page}"
    return api_get(url)


def fetch_user_events_atom(username, per_page=30):
    url = f"{GITHUB_ATOM_BASE}/{username}.atom"
    xml_text = fetch_atom_feed(url)
    entries = parse_atom_entries(xml_text)
    events = []
    for entry in entries[:per_page]:
        parsed = parse_atom_title_to_event(
            entry["title"],
            username,
            content_html=entry.get("content", ""),
            entry_id=entry["id"],
        )
        parsed["id"] = entry["id"]
        parsed["created_at"] = entry["updated"] or entry["published"]
        parsed["url"] = entry["url"]
        events.append(parsed)
    return events


def get_user_repos_from_html(username):
    url = f"{GITHUB_ATOM_BASE}/{username}?tab=repositories"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        html = resp.read().decode("utf-8")
    repos = re.findall(rf'href="/{username}/([^"/]+)"', html)
    seen = set()
    unique = []
    for r in repos:
        if r not in seen and r not in ("settings", "repositories", "stars", "followers", "following"):
            seen.add(r)
            unique.append(r)
    return unique


def fetch_releases_api(owner, repo, per_page=10):
    url = f"{GITHUB_API_BASE}/repos/{owner}/{repo}/releases?per_page={per_page}"
    releases = api_get(url)
    events = []
    for release in releases:
        if release.get("draft", True):
            continue
        assets = release.get("assets", [])
        if len(assets) == 0:
            continue
        tag_name = release.get("tag_name", "?")
        release_name = release.get("name", "") or ""
        published_at = release.get("published_at", release.get("created_at", ""))
        html_url = release.get("html_url", f"https://github.com/{owner}/{repo}/releases")
        if release_name and release_name != tag_name:
            body_text = f"{release_name} ({repo})"
        else:
            body_text = repo
        events.append(
            {
                "id": f"release-{owner}/{repo}/{tag_name}",
                "type": "ReleaseEvent",
                "repo": f"{owner}/{repo}",
                "summary": tag_name,
                "body": body_text,
                "created_at": published_at,
                "url": html_url,
                "user": owner,
            }
        )
    return events


def fetch_tags_atom(owner, repo, per_page=10, min_age_minutes=1):
    url = f"{GITHUB_ATOM_BASE}/{owner}/{repo}/tags.atom"
    try:
        xml_text = fetch_atom_feed(url)
    except Exception:
        return []
    root = ET.fromstring(xml_text)
    tags = []
    now = datetime.now(timezone.utc)
    for entry in root.findall("atom:entry", ATOM_NS)[:per_page]:
        title = entry.find("atom:title", ATOM_NS)
        updated = entry.find("atom:updated", ATOM_NS)
        link = entry.find("atom:link", ATOM_NS)
        tag_name = title.text if title is not None else ""
        link_href = link.get("href", "") if link is not None else ""
        created_str = updated.text if updated is not None and updated.text else ""
        if " " in created_str and "T" not in created_str:
            created_str = created_str.replace(" ", "T")
        if created_str and not created_str.endswith("Z") and "+" not in created_str:
            created_str += "Z"
        try:
            created_dt = datetime.fromisoformat(created_str.replace("Z", "+00:00"))
            age_minutes = (now - created_dt).total_seconds() / 60
            if age_minutes < min_age_minutes:
                continue
        except Exception:
            pass
        tags.append(
            {
                "id": f"release-{owner}/{repo}/{tag_name}",
                "type": "ReleaseEvent",
                "repo": f"{owner}/{repo}",
                "summary": tag_name,
                "body": repo,
                "created_at": created_str,
                "url": link_href or f"https://github.com/{owner}/{repo}/releases",
                "user": owner,
            }
        )
    return tags


def fetch_user_tags(username, per_page=20):
    all_tags = []
    try:
        repos = get_user_repos_from_html(username)
    except Exception as e:
        print(f"Error getting repos for {username}: {e}")
        return all_tags

    api_failed = False
    for repo in repos:
        if not api_failed:
            try:
                releases = fetch_releases_api(username, repo, per_page=5)
                all_tags.extend(releases)
                continue
            except RateLimitError:
                print(f"API rate limited for {username}/{repo}, falling back to tags.atom")
                api_failed = True
            except Exception as e:
                print(f"Error fetching releases API for {username}/{repo}: {e}")

        try:
            tags = fetch_tags_atom(username, repo, per_page=5, min_age_minutes=1)
            all_tags.extend(tags)
        except Exception as e:
            print(f"Error fetching tags for {username}/{repo}: {e}")

    all_tags.sort(key=lambda e: e.get("created_at", ""), reverse=True)
    seen_ids = set()
    unique_tags = []
    for tag in all_tags:
        if tag["id"] not in seen_ids:
            seen_ids.add(tag["id"])
            unique_tags.append(tag)
    return unique_tags[:per_page]


def fetch_user_events(username, per_page=30):
    try:
        events = fetch_user_events_api(username, per_page)
        formatted = []
        for event in events:
            f = format_event(event)
            f["user"] = username
            formatted.append(f)
    except RateLimitError:
        print(f"API rate limited, falling back to Atom feed for {username}")
        events = fetch_user_events_atom(username, per_page)
        formatted = events

    try:
        tags = fetch_user_tags(username, per_page)
        formatted.extend(tags)
    except Exception as e:
        print(f"Error fetching tags for {username}: {e}")

    formatted.sort(key=lambda e: e.get("created_at", ""), reverse=True)
    return formatted[:per_page]


def format_event(event):
    etype = event.get("type", "Unknown")
    repo_name = event.get("repo", {}).get("name", "unknown")
    created = event.get("created_at", "")
    payload = event.get("payload", {})

    if etype == "PushEvent":
        commits = payload.get("commits", [])
        count = len(commits)
        ref = payload.get("ref", "").replace("refs/heads/", "")
        msg = payload.get("commits", [{}])[0].get("message", "") if commits else ""
        summary = f"Push til {ref}"
        body = f"{count} commit{'s' if count != 1 else ''}"
        if msg:
            body += f": {msg[:80]}"
    elif etype == "CreateEvent":
        ref_type = payload.get("ref_type", "repository")
        summary = f"Oprettede {ref_type}"
        body = repo_name
    elif etype == "PullRequestEvent":
        action = payload.get("action", "updated")
        pr = payload.get("pull_request", {})
        title = pr.get("title", "")
        action_map = {"opened": "åbnet", "closed": "lukket", "merged": "merged", "reopened": "genåbnet"}
        summary = f"Pull request {action_map.get(action, action)}"
        body = f"{repo_name}: {title[:80]}"
    elif etype == "IssuesEvent":
        action = payload.get("action", "updated")
        issue = payload.get("issue", {})
        title = issue.get("title", "")
        action_map = {"opened": "åbnet", "closed": "lukket", "reopened": "genåbnet"}
        summary = f"Issue {action_map.get(action, action)}"
        body = f"{repo_name}: {title[:80]}"
    elif etype == "ReleaseEvent":
        action = payload.get("action", "published")
        release = payload.get("release", {})
        tag = release.get("tag_name", "")
        summary = f"Release {action}"
        body = f"{repo_name}: {tag}"
    elif etype == "WatchEvent":
        summary = "Starred repository"
        body = repo_name
    elif etype == "ForkEvent":
        summary = "Forked repository"
        body = repo_name
    else:
        summary = etype.replace("Event", "")
        body = repo_name

    return {
        "id": event.get("id", ""),
        "type": etype,
        "repo": repo_name,
        "summary": summary,
        "body": body,
        "created_at": created,
        "url": f"https://github.com/{repo_name}",
        "user": "",
    }


def get_new_events(state):
    new_events = []
    seen_ids = set(state.get("seen_events", []))

    for username in state.get("watched_users", ["storefyr"]):
        try:
            events = fetch_user_events(username)
        except Exception as e:
            print(f"Error fetching events for {username}: {e}")
            continue

        for event in events:
            eid = event.get("id", "")
            if eid and eid not in seen_ids:
                event["user"] = username
                new_events.append(event)
                seen_ids.add(eid)

    new_events.sort(key=lambda e: e.get("created_at", ""), reverse=True)
    return new_events, list(seen_ids)


def check_for_updates():
    lock_fd = acquire_lock(timeout=10)
    if lock_fd is None:
        print("Could not acquire lock, another instance may be running")
        return []

    try:
        state = load_state()
        new_events, seen_ids = get_new_events(state)
        notified_ids = set(state.get("notified_events", []))

        truly_new = []
        for event in new_events:
            eid = event.get("id", "")
            if eid and eid not in notified_ids:
                truly_new.append(event)
                notified_ids.add(eid)

        state["seen_events"] = seen_ids
        state["notified_events"] = list(notified_ids)[-MAX_NOTIFIED_STORED:]
        state["last_check"] = datetime.now(timezone.utc).isoformat()
        save_state(state)
        return truly_new
    finally:
        release_lock(lock_fd)


def get_watched_users():
    state = load_state()
    return state.get("watched_users", ["storefyr"])


def add_watched_user(username):
    username = username.strip().lower()
    state = load_state()
    users = state.get("watched_users", [])
    if username and username not in users:
        users.append(username)
        state["watched_users"] = users
        save_state(state)
    return users


def remove_watched_user(username):
    username = username.strip().lower()
    state = load_state()
    users = state.get("watched_users", [])
    if username in users and len(users) > 1:
        users.remove(username)
        state["watched_users"] = users
        save_state(state)
    return users


def get_recent_activity(limit=20):
    state = load_state()
    activities = []
    for username in state.get("watched_users", ["storefyr"]):
        try:
            events = fetch_user_events(username, per_page=limit)
            for event in events:
                event["user"] = username
                activities.append(event)
        except Exception as e:
            print(f"Error fetching activity for {username}: {e}")
    activities.sort(key=lambda e: e.get("created_at", ""), reverse=True)
    return activities[:limit]


def get_repo_details(owner, repo):
    try:
        repo_info = api_get(f"{GITHUB_API_BASE}/repos/{owner}/{repo}")
        releases = api_get(f"{GITHUB_API_BASE}/repos/{owner}/{repo}/releases?per_page=5")
        commits = api_get(f"{GITHUB_API_BASE}/repos/{owner}/{repo}/commits?per_page=5")
        return {
            "repo": repo_info,
            "releases": releases,
            "commits": commits,
        }
    except RateLimitError:
        return None
    except Exception as e:
        print(f"Error fetching repo details for {owner}/{repo}: {e}")
        return None


def set_notifications_enabled(enabled):
    state = load_state()
    state["notifications_enabled"] = enabled
    save_state(state)
    return enabled


def are_notifications_enabled():
    state = load_state()
    return state.get("notifications_enabled", True)


def is_notification_sound_enabled():
    state = load_state()
    return state.get("notification_sound", True)


def set_notification_sound(enabled):
    state = load_state()
    state["notification_sound"] = enabled
    save_state(state)
    return enabled


def get_notification_filter():
    state = load_state()
    default = [
        "PushEvent",
        "PullRequestEvent",
        "IssuesEvent",
        "ReleaseEvent",
        "CreateEvent",
        "DeleteEvent",
        "WatchEvent",
        "ForkEvent",
        "CommitCommentEvent",
    ]
    return state.get("notification_filter", default)


def set_notification_filter(event_types):
    state = load_state()
    state["notification_filter"] = event_types
    save_state(state)
    return event_types


def should_notify(event_type):
    if not are_notifications_enabled():
        return False
    allowed = get_notification_filter()
    return event_type in allowed


def filter_events_for_notification(events):
    return [e for e in events if should_notify(e.get("type", ""))]


def run_background_check():
    if not are_notifications_enabled():
        return {"status": "disabled", "new_events": [], "count": 0}

    try:
        new_events = check_for_updates()
        return {
            "status": "ok",
            "new_events": new_events,
            "count": len(new_events),
        }
    except Exception as e:
        return {"status": "error", "error": str(e), "new_events": [], "count": 0}


def reset_seen_events():
    state = load_state()
    state["seen_events"] = []
    state["notified_events"] = []
    save_state(state)
    return True


def publish_notification(summary, body, is_release=False):
    """Publish a notification via D-Bus (works without QML window).

    Uses org.freedesktop.Notifications D-Bus interface which is what
    Sailfish OS Nemo.Notifications ultimately calls. This works even
    when no QML window is visible.
    """
    try:
        category = "x-harbour.harbour-skodja.release" if is_release else "x-harbour.harbour-skodja.event"

        # Try using dbus-send first (always available on Sailfish OS)
        cmd = [
            "dbus-send",
            "--session",
            "--print-reply",
            "--dest=org.freedesktop.Notifications",
            "/org/freedesktop/Notifications",
            "org.freedesktop.Notifications.Notify",
            "string:harbour-skodja",  # app_name
            "uint32:0",  # replaces_id
            "string:harbour-skodja",  # app_icon
            "string:" + summary,  # summary
            "string:" + body,  # body
            "array:string:",  # actions
            "dict:string:variant:",  # hints
            "int32:5000",  # timeout
        ]

        # Add category hint so Sailfish OS knows which sound profile to use
        cmd[-3] = "dict:string:variant:category,s:{" + category + "}"

        result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            return True

        # Fallback: try gdbus
        cmd2 = [
            "gdbus",
            "call",
            "--session",
            "--dest",
            "org.freedesktop.Notifications",
            "--object-path",
            "/org/freedesktop/Notifications",
            "--method",
            "org.freedesktop.Notifications.Notify",
            "harbour-skodja",
            "0",
            "harbour-skodja",
            summary,
            body,
            "[]",
            "{'category': <'" + category + "'>}",
            "5000",
        ]
        result2 = subprocess.run(cmd2, capture_output=True, text=True, timeout=5)
        return result2.returncode == 0

    except Exception as e:
        print("Failed to publish D-Bus notification: " + str(e))
        return False


def check_and_notify():
    """Full background check: fetch updates and publish notifications via D-Bus.
    This is the main entry point for background notifications that work
    even when the app UI is not visible.
    """
    if not are_notifications_enabled():
        return {"status": "disabled", "notified": 0}

    try:
        new_events = check_for_updates()
        if not new_events:
            return {"status": "ok", "notified": 0}

        filtered = filter_events_for_notification(new_events)
        if not filtered:
            return {"status": "ok", "notified": 0}

        release_events = [e for e in filtered if e.get("type") == "ReleaseEvent"]
        other_events = [e for e in filtered if e.get("type") != "ReleaseEvent"]

        notified = 0

        if other_events:
            first = other_events[0]
            summary = "Skoðja: " + first.get("summary", "Ny aktivitet")
            body = first.get("user", "") + ": " + first.get("body", "")
            if len(other_events) > 1:
                body += " (+" + str(len(other_events) - 1) + " flere)"
            if publish_notification(summary, body, is_release=False):
                notified += 1

        if release_events:
            sound_enabled = is_notification_sound_enabled()
            first = release_events[0]
            summary = "Skoðja: " + first.get("summary", "Ny release")
            body = first.get("body", "")
            if len(release_events) > 1:
                body += " (+" + str(len(release_events) - 1) + " flere)"
            if publish_notification(summary, body, is_release=sound_enabled):
                notified += 1

        return {"status": "ok", "notified": notified}

    except Exception as e:
        return {"status": "error", "error": str(e), "notified": 0}


def run_daemon(interval_seconds=60):
    """Run as a persistent background daemon.
    Checks for new events and publishes notifications at regular intervals.
    This runs entirely in Python without any QML dependency.
    """
    print("Skoða daemon started (interval: {}s)".format(interval_seconds))
    while True:
        try:
            result = check_and_notify()
            if result.get("status") == "ok" and result.get("notified", 0) > 0:
                print("Skoða daemon: Published {} notification(s)".format(result["notified"]))
            elif result.get("status") == "error":
                print("Skoða daemon error: " + str(result.get("error", "unknown")))
        except Exception as e:
            print("Skoða daemon exception: " + str(e))
        time.sleep(interval_seconds)


if __name__ == "__main__":
    import sys

    interval = 60
    if len(sys.argv) > 1:
        try:
            interval = int(sys.argv[1])
        except ValueError:
            pass
    run_daemon(interval)
