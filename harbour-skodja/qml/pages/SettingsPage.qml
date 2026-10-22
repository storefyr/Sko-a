/****************************************************************************************
 * harbour-skodja - GitHub Activity Notifier for Sailfish OS
 * Copyright (C) 2026 storefyr
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 ****************************************************************************************/

import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: settingsPage
    allowedOrientations: defaultAllowedOrientations

    property var watchedUsers: []
    property bool notificationsEnabled: true
    property bool notificationSound: true

    RemorsePopup {
        id: settingsRemorse
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: "Indstillinger"
            }

            SectionHeader {
                text: "Overvågede brugere"
            }

            Repeater {
                model: watchedUsers
                delegate: ListItem {
                    id: userListItem
                    contentHeight: Theme.itemSizeSmall
                    Label {
                        anchors {
                            left: parent.left
                            leftMargin: Theme.horizontalPageMargin
                            verticalCenter: parent.verticalCenter
                        }
                        text: modelData
                        color: Theme.primaryColor
                    }
                    onClicked: {
                        userListItem.remorseDelete(function() {
                            appWindow.py.call("gitwatch.github_client.remove_watched_user", [modelData], function(users) {
                                watchedUsers = users
                                appWindow.watchedUsersChanged()
                            })
                        })
                    }
                }
            }

            TextField {
                id: newUserField
                width: parent.width
                label: "GitHub brugernavn"
                placeholderText: "f.eks. storefyr"
                EnterKey.onClicked: addUser()
            }

            Label {
                id: errorLabel
                visible: false
                width: parent.width
                x: Theme.horizontalPageMargin
                color: Theme.errorColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Tilføj bruger"
                onClicked: addUser()
            }

            SectionHeader {
                text: "Notifikationer"
            }

            TextSwitch {
                id: notifSwitch
                text: "Aktiver notifikationer"
                description: "Vis systemnotifikationer ved ny GitHub-aktivitet"
                checked: notificationsEnabled
                onCheckedChanged: {
                    appWindow.py.call("gitwatch.github_client.set_notifications_enabled", [checked], function() {})
                }
            }

            TextSwitch {
                id: soundSwitch
                text: "Lyd ved nye releases"
                description: "Brug Sailfish OS notifikationslyd ved nye releases"
                checked: notificationSound
                onCheckedChanged: {
                    appWindow.py.call("gitwatch.github_client.set_notification_sound", [checked], function() {})
                }
            }

            SectionHeader {
                text: "Notifikationsfilter"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "Vælg hvilke hændelsestyper der skal give notifikationer:"
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }

            TextSwitch {
                id: filterPush
                text: "Push (commits)"
                checked: true
                onCheckedChanged: updateFilter()
            }

            TextSwitch {
                id: filterPR
                text: "Pull requests"
                checked: true
                onCheckedChanged: updateFilter()
            }

            TextSwitch {
                id: filterIssues
                text: "Issues"
                checked: true
                onCheckedChanged: updateFilter()
            }

            TextSwitch {
                id: filterReleases
                text: "Releases"
                checked: true
                onCheckedChanged: updateFilter()
            }

            TextSwitch {
                id: filterCreate
                text: "Nye branches/repositories"
                checked: true
                onCheckedChanged: updateFilter()
            }

            TextSwitch {
                id: filterDelete
                text: "Slettede branches/tags"
                checked: true
                onCheckedChanged: updateFilter()
            }

            TextSwitch {
                id: filterStar
                text: "Stjerner (Watch)"
                checked: true
                onCheckedChanged: updateFilter()
            }

            TextSwitch {
                id: filterFork
                text: "Forks"
                checked: true
                onCheckedChanged: updateFilter()
            }

            TextSwitch {
                id: filterComment
                text: "Kommentarer"
                checked: true
                onCheckedChanged: updateFilter()
            }

            SectionHeader {
                text: "Statistik"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "Skoðja har kørt i " + statsUptime
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "Sidste tjek: " + statsLastCheck
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
            }

            SectionHeader {
                text: "API-forbrug"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "API-kald i alt: " + statsApiCalls + "\nCache hits (304): " + statsCacheHits + " (" + statsCacheRate + "%)\nRate-limited: " + statsRateLimited + " (cache: " + statsCachedOnLimit + ")\nAtom-fallbacks: " + statsAtomFallbacks + "\nAPI-fejl: " + statsApiErrors
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }

            SectionHeader {
                text: "Aktivitet"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "Tjek i alt: " + statsChecks + "\nTjek med nyt: " + statsChecksNew + "\nNotifikationer sendt: " + statsNotifs + "\nOvervågede brugere: " + statsUsers + "\nGemte hændelser: " + statsSeen
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "Sidste fejl: " + statsLastError + " (" + statsLastErrorTime + ")"
                color: statsApiErrors > 0 ? Theme.errorColor : Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
                visible: statsApiErrors > 0
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Nulstil statistik"
                onClicked: {
                    settingsRemorse.execute("Nulstil statistik?", function() {
                        appWindow.py.call("gitwatch.github_client.reset_statistics", [], function() {
                            refreshStatistics()
                        })
                    })
                }
            }

            SectionHeader {
                text: "Avanceret"
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Nulstil sete hændelser"
                onClicked: {
                    appWindow.py.call("gitwatch.github_client.reset_seen_events", [], function() {
                        settingsRemorse.execute("Nulstillet", function() {})
                    })
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "Nulstil listen over sete hændelser, så alle eksisterende aktiviteter vises igen."
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }

            SectionHeader {
                text: "Om"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "Skoðja 0.9.3\nOvervåger GitHub-aktivitet for udvalgte brugere.\nTjekker via baggrundsdaemon hvert minut.\nK\u00f8rer som baggrundsdaemon.\nLyd via Sailfish OS indstillinger."
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }
        }

        VerticalScrollDecorator {}
    }

    function addUser() {
        var username = newUserField.text.trim().toLowerCase()
        if (username.length === 0) return
        appWindow.py.call("gitwatch.github_client.add_watched_user", [username], function(users) {
            console.log("add_watched_user returned: " + JSON.stringify(users))
            if (users.indexOf(username) === -1) {
                errorLabel.text = "Brugeren findes allerede"
                errorLabel.visible = true
            } else {
                errorLabel.visible = false
                watchedUsers = users
                newUserField.text = ""
                appWindow.watchedUsersChanged()
            }
        })
    }

    function loadUsers() {
        appWindow.py.call("gitwatch.github_client.get_watched_users", [], function(users) {
            console.log("get_watched_users returned: " + JSON.stringify(users))
            watchedUsers = users
        })
    }

    function loadFilter() {
        appWindow.py.call("gitwatch.github_client.get_notification_filter", [], function(filter) {
            console.log("notification_filter: " + JSON.stringify(filter))
            filterPush.checked = filter.indexOf("PushEvent") !== -1
            filterPR.checked = filter.indexOf("PullRequestEvent") !== -1
            filterIssues.checked = filter.indexOf("IssuesEvent") !== -1
            filterReleases.checked = filter.indexOf("ReleaseEvent") !== -1
            filterCreate.checked = filter.indexOf("CreateEvent") !== -1
            filterDelete.checked = filter.indexOf("DeleteEvent") !== -1
            filterStar.checked = filter.indexOf("WatchEvent") !== -1
            filterFork.checked = filter.indexOf("ForkEvent") !== -1
            filterComment.checked = filter.indexOf("CommitCommentEvent") !== -1
        })
    }

    function updateFilter() {
        var filter = []
        if (filterPush.checked) filter.push("PushEvent")
        if (filterPR.checked) filter.push("PullRequestEvent")
        if (filterIssues.checked) filter.push("IssuesEvent")
        if (filterReleases.checked) filter.push("ReleaseEvent")
        if (filterCreate.checked) filter.push("CreateEvent")
        if (filterDelete.checked) filter.push("DeleteEvent")
        if (filterStar.checked) filter.push("WatchEvent")
        if (filterFork.checked) filter.push("ForkEvent")
        if (filterComment.checked) filter.push("CommitCommentEvent")
        appWindow.py.call("gitwatch.github_client.set_notification_filter", [filter], function() {})
    }

    Component.onCompleted: {
        loadUsers()
        loadFilter()
        appWindow.py.call("gitwatch.github_client.are_notifications_enabled", [], function(enabled) {
            notificationsEnabled = enabled
            notifSwitch.checked = enabled
        })
        appWindow.py.call("gitwatch.github_client.is_notification_sound_enabled", [], function(enabled) {
            notificationSound = enabled
            soundSwitch.checked = enabled
        })
        refreshStatistics()
    }

    property string statsUptime: "..."
    property string statsLastCheck: "..."
    property int statsApiCalls: 0
    property int statsCacheHits: 0
    property real statsCacheRate: 0
    property int statsRateLimited: 0
    property int statsCachedOnLimit: 0
    property int statsAtomFallbacks: 0
    property int statsApiErrors: 0
    property int statsChecks: 0
    property int statsChecksNew: 0
    property int statsNotifs: 0
    property int statsUsers: 0
    property int statsSeen: 0
    property string statsLastError: "Ingen"
    property string statsLastErrorTime: "-"

    function refreshStatistics() {
        appWindow.py.call("gitwatch.github_client.get_statistics", [], function(s) {
            statsUptime = s.uptime
            statsLastCheck = s.last_check
            statsApiCalls = s.api_calls_total
            statsCacheHits = s.api_calls_304
            statsCacheRate = s.cache_hit_rate
            statsRateLimited = s.api_rate_limited
            statsCachedOnLimit = s.api_cached_on_rate_limit
            statsAtomFallbacks = s.atom_fallbacks
            statsApiErrors = s.api_errors
            statsChecks = s.checks_total
            statsChecksNew = s.checks_with_new_events
            statsNotifs = s.notifications_sent
            statsUsers = s.watched_users
            statsSeen = s.seen_events_count
            statsLastError = s.last_error
            statsLastErrorTime = s.last_error_time
        })
    }

    Connections {
        target: appWindow
        onWatchedUsersChanged: loadUsers()
    }
}
