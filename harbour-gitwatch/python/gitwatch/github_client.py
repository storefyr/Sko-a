# harbour-gitwatch - GitHub Activity Notifier for Sailfish OS
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

import json
import os
import re
import urllib.request
import urllib.error
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

GITHUB_API_BASE = "https://api.github.com"
GITHUB_ATOM_BASE = "https://github.com"
USER_AGENT = "harbour-gitwatch/0.1 (Sailfish OS)"


def _get_data_dir():
    xdg_data = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
    return os.path.join(xdg_data, "com.storefyr", "harbour-gitwatch")


DATA_DIR = _get_data_dir()
STATE_FILE = os.path.join(DATA_DIR, "state.json")
MAX_EVENTS_STORED = 100
ATOM_NS = {"atom": "http://www.w3.org/2005/Atom"}


def ensure_data_dir():
    os.makedirs(DATA_DIR, exist_ok=True)


def load_state():
    ensure_data_dir()
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r") as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            pass
    return {"last_check": None, "seen_events": [], "watched_users": ["storefyr"], "notifications_enabled": True}


def save_state(state):
    ensure_data_dir()
    state["seen_events"] = state["seen_events"][-MAX_EVENTS_STORED:]
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


def fetch_user_events(username, per_page=30):
    try:
        events = fetch_user_events_api(username, per_page)
        formatted = []
        for event in events:
            f = format_event(event)
            f["user"] = username
            formatted.append(f)
        return formatted
    except RateLimitError:
        print(f"API rate limited, falling back to Atom feed for {username}")
        return fetch_user_events_atom(username, per_page)


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
    state = load_state()
    new_events, seen_ids = get_new_events(state)
    state["seen_events"] = seen_ids
    state["last_check"] = datetime.now(timezone.utc).isoformat()
    save_state(state)
    return new_events


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
    save_state(state)
    return True
