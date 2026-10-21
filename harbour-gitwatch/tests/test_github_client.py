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

"""Tests for gitwatch.github_client module."""

import os
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "python"))

from gitwatch import github_client  # noqa: E402

ATOM_FEED_SAMPLE = """<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xmlns:media="http://search.yahoo.com/mrss/" xml:lang="en-US">
  <id>tag:github.com,2008:/testuser</id>
  <link type="text/html" rel="alternate" href="https://github.com/testuser"/>
  <link type="application/atom+xml" rel="self" href="https://github.com/testuser.atom"/>
  <title>GitHub Public Timeline Feed</title>
  <updated>2026-10-20T10:00:00Z</updated>
  <entry>
    <id>tag:github.com,2008:push/12345</id>
    <published>2026-10-20 10:00:00 UTC</published>
    <updated>2026-10-20 10:00:00 UTC</updated>
    <link type="text/html" rel="alternate" href="https://github.com/testuser/myrepo/compare/abc...def"/>
    <title type="html">testuser pushed myrepo</title>
    <author>
      <name>testuser</name>
      <uri>https://github.com/testuser</uri>
    </author>
    <content type="html">&lt;div&gt;&lt;a href=&quot;/testuser/myrepo&quot;&gt;testuser/myrepo&lt;/a&gt;&lt;/div&gt;</content>
  </entry>
  <entry>
    <id>tag:github.com,2008:pr_created/67890</id>
    <published>2026-10-20 09:00:00 UTC</published>
    <updated>2026-10-20 09:00:00 UTC</updated>
    <link type="text/html" rel="alternate" href="https://github.com/testuser/myrepo/pull/1"/>
    <title type="html">testuser opened a pull request in myrepo</title>
    <author>
      <name>testuser</name>
      <uri>https://github.com/testuser</uri>
    </author>
    <content type="html">&lt;div&gt;&lt;a href=&quot;/testuser/myrepo/pull/1&quot;&gt;PR #1&lt;/a&gt;&lt;/div&gt;</content>
  </entry>
  <entry>
    <id>tag:github.com,2008:push/11111</id>
    <published>2026-10-20 08:00:00 UTC</published>
    <updated>2026-10-20 08:00:00 UTC</updated>
    <link type="text/html" rel="alternate" href="https://github.com/testuser/otherrepo/compare/xyz...123"/>
    <title type="html">testuser created a branch</title>
    <author>
      <name>testuser</name>
      <uri>https://github.com/testuser</uri>
    </author>
    <content type="html">&lt;div&gt;&lt;a href=&quot;/testuser/otherrepo&quot;&gt;testuser/otherrepo&lt;/a&gt;&lt;/div&gt;</content>
  </entry>
</feed>
"""

API_EVENTS_SAMPLE = [
    {
        "id": "12345",
        "type": "PushEvent",
        "repo": {"name": "testuser/myrepo"},
        "created_at": "2026-10-20T10:00:00Z",
        "payload": {
            "ref": "refs/heads/main",
            "commits": [
                {"message": "Fix bug in parser"},
                {"message": "Add tests"},
            ],
        },
    },
    {
        "id": "67890",
        "type": "PullRequestEvent",
        "repo": {"name": "testuser/myrepo"},
        "created_at": "2026-10-20T09:00:00Z",
        "payload": {
            "action": "opened",
            "pull_request": {"title": "Add new feature"},
        },
    },
    {
        "id": "11111",
        "type": "CreateEvent",
        "repo": {"name": "testuser/newrepo"},
        "created_at": "2026-10-20T08:00:00Z",
        "payload": {"ref_type": "repository"},
    },
]


class TestStateManagement(unittest.TestCase):
    """Test state loading and saving."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.original_data_dir = github_client.DATA_DIR
        self.original_state_file = github_client.STATE_FILE
        self.original_lock_file = github_client.LOCK_FILE
        github_client.DATA_DIR = self.temp_dir
        github_client.STATE_FILE = os.path.join(self.temp_dir, "state.json")
        github_client.LOCK_FILE = os.path.join(self.temp_dir, "state.lock")

    def tearDown(self):
        github_client.DATA_DIR = self.original_data_dir
        github_client.STATE_FILE = self.original_state_file
        github_client.LOCK_FILE = self.original_lock_file
        import shutil

        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_default_state(self):
        state = github_client.load_state()
        self.assertEqual(state["watched_users"], ["storefyr"])
        self.assertTrue(state["notifications_enabled"])
        self.assertIsNone(state["last_check"])
        self.assertEqual(state["seen_events"], [])
        self.assertEqual(state["notified_events"], [])

    def test_save_and_load_state(self):
        state = {
            "last_check": "2026-10-20T10:00:00Z",
            "seen_events": ["1", "2", "3"],
            "notified_events": ["1"],
            "watched_users": ["user1", "user2"],
            "notifications_enabled": False,
        }
        github_client.save_state(state)
        loaded = github_client.load_state()
        self.assertEqual(loaded["watched_users"], ["user1", "user2"])
        self.assertFalse(loaded["notifications_enabled"])
        self.assertEqual(loaded["notified_events"], ["1"])

    def test_corrupt_state_file(self):
        with open(github_client.STATE_FILE, "w") as f:
            f.write("not valid json {{{")
        state = github_client.load_state()
        self.assertEqual(state["watched_users"], ["storefyr"])

    def test_max_events_stored(self):
        state = github_client.load_state()
        state["seen_events"] = [str(i) for i in range(github_client.MAX_EVENTS_STORED + 100)]
        github_client.save_state(state)
        loaded = github_client.load_state()
        self.assertEqual(len(loaded["seen_events"]), github_client.MAX_EVENTS_STORED)


class TestUserManagement(unittest.TestCase):
    """Test watched user management."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.original_data_dir = github_client.DATA_DIR
        self.original_state_file = github_client.STATE_FILE
        self.original_lock_file = github_client.LOCK_FILE
        github_client.DATA_DIR = self.temp_dir
        github_client.STATE_FILE = os.path.join(self.temp_dir, "state.json")
        github_client.LOCK_FILE = os.path.join(self.temp_dir, "state.lock")

    def tearDown(self):
        github_client.DATA_DIR = self.original_data_dir
        github_client.STATE_FILE = self.original_state_file
        github_client.LOCK_FILE = self.original_lock_file
        import shutil

        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_get_default_watched_users(self):
        users = github_client.get_watched_users()
        self.assertEqual(users, ["storefyr"])

    def test_add_watched_user(self):
        users = github_client.add_watched_user("octocat")
        self.assertIn("octocat", users)
        self.assertIn("storefyr", users)

    def test_add_duplicate_user(self):
        github_client.add_watched_user("octocat")
        users = github_client.add_watched_user("octocat")
        self.assertEqual(users.count("octocat"), 1)

    def test_remove_watched_user(self):
        github_client.add_watched_user("octocat")
        users = github_client.remove_watched_user("octocat")
        self.assertNotIn("octocat", users)
        self.assertIn("storefyr", users)

    def test_cannot_remove_last_user(self):
        users = github_client.remove_watched_user("storefyr")
        self.assertIn("storefyr", users)


class TestAtomParsing(unittest.TestCase):
    """Test Atom feed parsing."""

    def test_parse_atom_entries(self):
        entries = github_client.parse_atom_entries(ATOM_FEED_SAMPLE)
        self.assertEqual(len(entries), 3)
        self.assertEqual(entries[0]["title"], "testuser pushed myrepo")
        self.assertIn("push/12345", entries[0]["id"])

    def test_parse_push_event(self):
        result = github_client.parse_atom_title_to_event(
            "testuser pushed myrepo",
            "testuser",
            content_html='<a href="/testuser/myrepo">testuser/myrepo</a>',
            entry_id="tag:github.com,2008:push/12345",
        )
        self.assertEqual(result["type"], "PushEvent")
        self.assertIn("myrepo", result["summary"])
        self.assertEqual(result["repo"], "testuser/myrepo")

    def test_parse_pr_event(self):
        result = github_client.parse_atom_title_to_event(
            "testuser opened a pull request in myrepo",
            "testuser",
            content_html='<a href="/testuser/myrepo/pull/1">PR #1</a>',
            entry_id="tag:github.com,2008:pr_created/67890",
        )
        self.assertEqual(result["type"], "PullRequestEvent")
        self.assertIn("#1", result["body"])
        self.assertEqual(result["repo"], "testuser/myrepo")

    def test_parse_create_branch_event(self):
        result = github_client.parse_atom_title_to_event(
            "testuser created a branch",
            "testuser",
            content_html='<a href="/testuser/otherrepo">testuser/otherrepo</a>',
            entry_id="tag:github.com,2008:push/11111",
        )
        self.assertEqual(result["type"], "CreateEvent")
        self.assertIn("branch", result["summary"].lower())

    def test_parse_unknown_event(self):
        result = github_client.parse_atom_title_to_event(
            "testuser did something weird",
            "testuser",
            content_html="",
            entry_id="tag:github.com,2008:unknown/123",
        )
        self.assertEqual(result["type"], "Activity")

    def test_fetch_user_events_atom(self):
        with patch.object(github_client, "fetch_atom_feed", return_value=ATOM_FEED_SAMPLE):
            events = github_client.fetch_user_events_atom("testuser", per_page=10)
        self.assertEqual(len(events), 3)
        self.assertEqual(events[0]["type"], "PushEvent")
        self.assertEqual(events[1]["type"], "PullRequestEvent")


class TestApiEventFormatting(unittest.TestCase):
    """Test GitHub API event formatting."""

    def test_format_push_event(self):
        event = API_EVENTS_SAMPLE[0]
        result = github_client.format_event(event)
        self.assertEqual(result["type"], "PushEvent")
        self.assertIn("main", result["summary"])
        self.assertIn("2 commits", result["body"])

    def test_format_pr_event(self):
        event = API_EVENTS_SAMPLE[1]
        result = github_client.format_event(event)
        self.assertEqual(result["type"], "PullRequestEvent")
        self.assertIn("åbnet", result["summary"])

    def test_format_create_event(self):
        event = API_EVENTS_SAMPLE[2]
        result = github_client.format_event(event)
        self.assertEqual(result["type"], "CreateEvent")
        self.assertIn("repository", result["summary"])


class TestNotificationSettings(unittest.TestCase):
    """Test notification enable/disable."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.original_data_dir = github_client.DATA_DIR
        self.original_state_file = github_client.STATE_FILE
        self.original_lock_file = github_client.LOCK_FILE
        github_client.DATA_DIR = self.temp_dir
        github_client.STATE_FILE = os.path.join(self.temp_dir, "state.json")
        github_client.LOCK_FILE = os.path.join(self.temp_dir, "state.lock")

    def tearDown(self):
        github_client.DATA_DIR = self.original_data_dir
        github_client.STATE_FILE = self.original_state_file
        github_client.LOCK_FILE = self.original_lock_file
        import shutil

        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_default_enabled(self):
        self.assertTrue(github_client.are_notifications_enabled())

    def test_disable_notifications(self):
        github_client.set_notifications_enabled(False)
        self.assertFalse(github_client.are_notifications_enabled())

    def test_enable_notifications(self):
        github_client.set_notifications_enabled(False)
        github_client.set_notifications_enabled(True)
        self.assertTrue(github_client.are_notifications_enabled())


class TestNotificationFilter(unittest.TestCase):
    """Test notification filter functionality."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.original_data_dir = github_client.DATA_DIR
        self.original_state_file = github_client.STATE_FILE
        self.original_lock_file = github_client.LOCK_FILE
        github_client.DATA_DIR = self.temp_dir
        github_client.STATE_FILE = os.path.join(self.temp_dir, "state.json")
        github_client.LOCK_FILE = os.path.join(self.temp_dir, "state.lock")

    def tearDown(self):
        github_client.DATA_DIR = self.original_data_dir
        github_client.STATE_FILE = self.original_state_file
        github_client.LOCK_FILE = self.original_lock_file
        import shutil

        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_default_filter_includes_all(self):
        filter_types = github_client.get_notification_filter()
        self.assertIn("PushEvent", filter_types)
        self.assertIn("ReleaseEvent", filter_types)
        self.assertIn("PullRequestEvent", filter_types)

    def test_set_filter_releases_only(self):
        github_client.set_notification_filter(["ReleaseEvent"])
        filter_types = github_client.get_notification_filter()
        self.assertEqual(filter_types, ["ReleaseEvent"])

    def test_should_notify_with_filter(self):
        github_client.set_notification_filter(["ReleaseEvent"])
        self.assertTrue(github_client.should_notify("ReleaseEvent"))
        self.assertFalse(github_client.should_notify("PushEvent"))

    def test_should_notify_disabled(self):
        github_client.set_notifications_enabled(False)
        self.assertFalse(github_client.should_notify("ReleaseEvent"))

    def test_filter_events_for_notification(self):
        github_client.set_notification_filter(["ReleaseEvent"])
        events = [
            {"type": "PushEvent", "summary": "Push"},
            {"type": "ReleaseEvent", "summary": "Release"},
            {"type": "IssuesEvent", "summary": "Issue"},
        ]
        filtered = github_client.filter_events_for_notification(events)
        self.assertEqual(len(filtered), 1)
        self.assertEqual(filtered[0]["type"], "ReleaseEvent")


class TestEventDeduplication(unittest.TestCase):
    """Test event deduplication logic."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.original_data_dir = github_client.DATA_DIR
        self.original_state_file = github_client.STATE_FILE
        self.original_lock_file = github_client.LOCK_FILE
        github_client.DATA_DIR = self.temp_dir
        github_client.STATE_FILE = os.path.join(self.temp_dir, "state.json")
        github_client.LOCK_FILE = os.path.join(self.temp_dir, "state.lock")

    def tearDown(self):
        github_client.DATA_DIR = self.original_data_dir
        github_client.STATE_FILE = self.original_state_file
        github_client.LOCK_FILE = self.original_lock_file
        import shutil

        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_get_new_events_deduplication(self):
        state = github_client.load_state()
        fake_events = [
            {
                "id": "1",
                "type": "PushEvent",
                "repo": "a/b",
                "summary": "Push",
                "body": "test",
                "created_at": "2026-01-01",
                "url": "",
            },
            {
                "id": "2",
                "type": "PushEvent",
                "repo": "a/b",
                "summary": "Push",
                "body": "test",
                "created_at": "2026-01-02",
                "url": "",
            },
        ]
        with patch.object(github_client, "fetch_user_events", return_value=fake_events):
            new_events, seen_ids = github_client.get_new_events(state)
            self.assertEqual(len(new_events), 2)
            new_events2, _ = github_client.get_new_events({**state, "seen_events": seen_ids})
            self.assertEqual(len(new_events2), 0)

    def test_check_for_updates_integration(self):
        fake_events = [
            {
                "id": "1",
                "type": "PushEvent",
                "repo": "a/b",
                "summary": "Push",
                "body": "test",
                "created_at": "2026-01-01",
                "url": "",
            },
        ]
        with patch.object(github_client, "fetch_user_events", return_value=fake_events):
            new_events = github_client.check_for_updates()
            self.assertEqual(len(new_events), 1)
            new_events2 = github_client.check_for_updates()
            self.assertEqual(len(new_events2), 0)

    def test_check_for_updates_no_duplicate_notifications(self):
        fake_events = [
            {
                "id": "release-123",
                "type": "ReleaseEvent",
                "repo": "a/b",
                "summary": "Ny release",
                "body": "v1.0 i a/b",
                "created_at": "2026-01-01",
                "url": "https://github.com/a/b/releases",
            },
            {
                "id": "push-456",
                "type": "PushEvent",
                "repo": "a/b",
                "summary": "Push til main",
                "body": "3 commits",
                "created_at": "2026-01-02",
                "url": "",
            },
        ]
        with patch.object(github_client, "fetch_user_events", return_value=fake_events):
            first = github_client.check_for_updates()
            self.assertEqual(len(first), 2)

            second = github_client.check_for_updates()
            self.assertEqual(len(second), 0)

            third = github_client.check_for_updates()
            self.assertEqual(len(third), 0)

            state = github_client.load_state()
            self.assertIn("release-123", state["notified_events"])
            self.assertIn("push-456", state["notified_events"])

    def test_notified_events_persisted(self):
        github_client.reset_seen_events()
        fake_events = [
            {
                "id": "event-1",
                "type": "ReleaseEvent",
                "repo": "a/b",
                "summary": "Ny release",
                "body": "v1.0",
                "created_at": "2026-01-01",
                "url": "",
            },
        ]
        with patch.object(github_client, "fetch_user_events", return_value=fake_events):
            github_client.check_for_updates()

            state = github_client.load_state()
            self.assertEqual(len(state["notified_events"]), 1)
            self.assertEqual(state["notified_events"][0], "event-1")


class TestRateLimitHandling(unittest.TestCase):
    """Test rate limit fallback to Atom feed."""

    def test_fallback_to_atom_on_rate_limit(self):
        rate_limit_error = github_client.RateLimitError("GitHub API rate limit exceeded")
        with patch.object(github_client, "api_get", side_effect=rate_limit_error):
            with patch.object(github_client, "fetch_user_events_atom", return_value=[]) as mock_atom:
                github_client.fetch_user_events("testuser")
                mock_atom.assert_called_once()


class TestQmlSyntax(unittest.TestCase):
    """Basic validation of QML files."""

    QML_DIR = os.path.join(os.path.dirname(__file__), "..", "qml")

    def test_qml_files_exist(self):
        expected_files = [
            "harbour-gitwatch.qml",
            "pages/MainPage.qml",
            "pages/SettingsPage.qml",
            "cover/CoverPage.qml",
            "background-check.qml",
        ]
        for f in expected_files:
            path = os.path.join(self.QML_DIR, f)
            self.assertTrue(os.path.exists(path), f"Missing QML file: {f}")

    def test_qml_files_have_imports(self):
        qml_files = [
            "harbour-gitwatch.qml",
            "pages/MainPage.qml",
            "pages/SettingsPage.qml",
            "cover/CoverPage.qml",
        ]
        for f in qml_files:
            path = os.path.join(self.QML_DIR, f)
            with open(path) as fh:
                content = fh.read()
            self.assertIn("import QtQuick", content, f"{f} missing QtQuick import")
            self.assertIn("import Sailfish.Silica", content, f"{f} missing Silica import")

    def test_qml_balanced_braces(self):
        qml_files = [
            "harbour-gitwatch.qml",
            "pages/MainPage.qml",
            "pages/SettingsPage.qml",
            "cover/CoverPage.qml",
            "background-check.qml",
        ]
        for f in qml_files:
            path = os.path.join(self.QML_DIR, f)
            with open(path) as fh:
                content = fh.read()
            open_braces = content.count("{")
            close_braces = content.count("}")
            self.assertEqual(
                open_braces, close_braces, f"{f} has unbalanced braces: {open_braces} open vs {close_braces} close"
            )


class TestPackagingFiles(unittest.TestCase):
    """Validate RPM packaging files."""

    RPM_DIR = os.path.join(os.path.dirname(__file__), "..", "rpm")

    def test_spec_file_exists(self):
        self.assertTrue(os.path.exists(os.path.join(self.RPM_DIR, "harbour-gitwatch.spec")))

    def test_desktop_file_exists(self):
        desktop_path = os.path.join(os.path.dirname(__file__), "..", "harbour-gitwatch.desktop")
        self.assertTrue(os.path.exists(desktop_path))

    def test_spec_has_required_fields(self):
        with open(os.path.join(self.RPM_DIR, "harbour-gitwatch.spec")) as f:
            content = f.read()
        self.assertIn("Name:", content)
        self.assertIn("Version:", content)
        self.assertIn("Summary:", content)
        self.assertIn("License:", content)

    def test_icons_exist(self):
        icons_dir = os.path.join(os.path.dirname(__file__), "..", "icons")
        for size in [86, 108, 128, 256]:
            path = os.path.join(icons_dir, f"harbour-gitwatch-{size}.png")
            self.assertTrue(os.path.exists(path), f"Missing icon: {size}x{size}")


if __name__ == "__main__":
    unittest.main()
