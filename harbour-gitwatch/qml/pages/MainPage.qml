/****************************************************************************************
 * harbour-gitwatch - GitHub Activity Notifier for Sailfish OS
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
import io.thp.pyotherside 1.5
import Nemo.Notifications 1.0

Page {
    id: mainPage
    allowedOrientations: defaultAllowedOrientations

    property var activities: []
    property var watchedUsers: []
    property bool loading: false

    property bool notificationSound: true

    Notification {
        id: notification
        appName: "harbour-gitwatch"
        appIcon: "harbour-gitwatch"
        category: "gitwatch.event"
        previewSummary: ""
        previewBody: ""
        summary: ""
        body: ""
        sound: mainPage.notificationSound ? "default" : ""
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        header: PageHeader {
            title: "GitWatch"
        }

        PullDownMenu {
            MenuItem {
                text: "Indstillinger"
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: "Tjek nu"
                onClicked: refresh()
            }
            MenuItem {
                text: "Test notifikation"
                onClicked: showNotification("Test", "Dette er en test-notifikation fra GitWatch")
            }
        }

        model: ListModel { id: activityModel }

        section.property: "dateGroup"
        section.delegate: SectionHeader {
            text: section
            height: Theme.itemSizeSmall
        }

        delegate: ListItem {
            id: delegate
            contentHeight: Theme.itemSizeExtraLarge

            Column {
                anchors {
                    fill: parent
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.horizontalPageMargin
                    topMargin: Theme.paddingMedium
                    bottomMargin: Theme.paddingMedium
                }
                spacing: Theme.paddingSmall

                Label {
                    text: model.summary
                    color: delegate.highlighted ? Theme.highlightColor : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeMedium
                    font.bold: true
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                }

                Label {
                    text: model.body
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    maximumLineCount: 1
                }

                Row {
                    width: parent.width
                    spacing: Theme.paddingMedium

                    Label {
                        text: model.user + " → " + model.repo
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        width: parent.width - timeLabel.width - parent.spacing
                        truncationMode: TruncationMode.Fade
                    }

                    Label {
                        id: timeLabel
                        text: formatTime(model.created_at)
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            onClicked: {
                if (model.url) {
                    Qt.openUrlExternally(model.url)
                }
            }
        }

        ViewPlaceholder {
            enabled: activityModel.count === 0 && !loading
            text: "Ingen aktivitet endnu"
            hintText: "Træk ned for at opdatere"
        }

        VerticalScrollDecorator {}
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: loading
        size: BusyIndicatorSize.Large
    }

    Timer {
        id: autoRefreshTimer
        interval: 6000
        running: true
        repeat: true
        onTriggered: {
            checkForNewEvents()
            refresh()
        }
    }

    function formatTime(isoString) {
        if (!isoString) return ""
        var date = new Date(isoString)
        var now = new Date()
        var diff = now - date
        var minutes = Math.floor(diff / 60000)
        var hours = Math.floor(diff / 3600000)
        var days = Math.floor(diff / 86400000)

        if (minutes < 1) return "lige nu"
        if (minutes < 60) return minutes + " min"
        if (hours < 24) return hours + " t"
        if (days < 7) return days + " d"
        return date.toLocaleDateString("da-DK")
    }

    function formatDateGroup(isoString) {
        if (!isoString) return ""
        var date = new Date(isoString)
        var now = new Date()
        var diff = now - date
        var days = Math.floor(diff / 86400000)

        if (days === 0) return "I dag"
        if (days === 1) return "I går"
        if (days < 7) return date.toLocaleDateString("da-DK", { weekday: "long" })
        return date.toLocaleDateString("da-DK")
    }

    property bool notificationsEnabled: true

    function checkForNewEvents() {
        appWindow.py.call("gitwatch.github_client.check_for_updates", [], function(newEvents) {
            appWindow.py.call("gitwatch.github_client.filter_events_for_notification", [newEvents], function(filtered) {
                if (filtered.length > 0) {
                    var firstEvent = filtered[0]
                    var summaryText = "GitWatch: " + firstEvent.summary
                    var bodyText = (firstEvent.user || "") + ": " + firstEvent.body
                    if (filtered.length > 1) {
                        bodyText += " (+" + (filtered.length - 1) + " flere)"
                    }
                    showNotification(summaryText, bodyText)
                }
            })
        })
    }

    function showNotification(summaryText, bodyText) {
        appWindow.py.call("gitwatch.github_client.are_notifications_enabled", [], function(enabled) {
            notificationsEnabled = enabled
            if (!enabled) {
                console.log("Notifications disabled in settings, skipping")
                return
            }
            appWindow.py.call("gitwatch.github_client.is_notification_sound_enabled", [], function(soundEnabled) {
                notificationSound = soundEnabled
                notification.sound = soundEnabled ? "default" : ""
                notification.previewSummary = summaryText
                notification.previewBody = bodyText
                notification.summary = summaryText
                notification.body = bodyText
                notification.publish()
            })
        })
    }

    function refresh() {
        loading = true
        appWindow.py.call("gitwatch.github_client.get_recent_activity", [30], function(result) {
            activityModel.clear()
            for (var k = 0; k < result.length; k++) {
                var item = result[k]
                item.dateGroup = formatDateGroup(item.created_at)
                activityModel.append(item)
            }
            loading = false
        })
        appWindow.py.call("gitwatch.github_client.get_watched_users", [], function(users) {
            watchedUsers = users
        })
    }

    Component.onCompleted: {
        refresh()
        appWindow.py.call("gitwatch.github_client.are_notifications_enabled", [], function(enabled) {
            console.log("Notifications enabled: " + enabled)
        })
    }

    Connections {
        target: appWindow
        onApplicationActiveChanged: {
            if (appWindow.applicationActive) {
                autoRefreshTimer.start()
                refresh()
            } else {
                autoRefreshTimer.stop()
            }
        }
    }
}
