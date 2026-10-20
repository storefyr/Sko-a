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

    Notification {
        id: notification
        appName: "GitWatch"
        appIcon: "harbour-gitwatch"
        category: "gitwatch.event"
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
        }

        model: ListModel { id: activityModel }

        section.property: "dateGroup"
        section.delegate: SectionHeader {
            text: section
            height: Theme.itemSizeSmall
        }

        delegate: ListItem {
            id: delegate
            contentHeight: Theme.itemSizeLarge

            Row {
                anchors {
                    fill: parent
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.horizontalPageMargin
                }
                spacing: Theme.paddingMedium

                Image {
                    id: eventIcon
                    anchors.verticalCenter: parent.verticalCenter
                    source: getEventIcon(model.type)
                    width: Theme.iconSizeMedium
                    height: Theme.iconSizeMedium
                    sourceSize.width: Theme.iconSizeMedium
                    sourceSize.height: Theme.iconSizeMedium
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - eventIcon.width - timeLabel.width - 2 * parent.spacing
                    spacing: Theme.paddingMedium

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

                    Label {
                        text: model.user + " → " + model.repo
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        width: parent.width
                        truncationMode: TruncationMode.Fade
                    }
                }

                Label {
                    id: timeLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: formatTime(model.created_at)
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
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

    function getEventIcon(eventType) {
        var icons = {
            "PushEvent": "image://theme/icon-m-up",
            "PullRequestEvent": "image://theme/icon-m-attention",
            "IssuesEvent": "image://theme/icon-m-question",
            "CreateEvent": "image://theme/icon-m-add",
            "DeleteEvent": "image://theme/icon-m-remove",
            "ReleaseEvent": "image://theme/icon-m-levels",
            "WatchEvent": "image://theme/icon-m-favorite",
            "ForkEvent": "image://theme/icon-m-levels",
            "CommitCommentEvent": "image://theme/icon-m-chat",
            "IssueCommentEvent": "image://theme/icon-m-chat",
            "PullRequestReviewEvent": "image://theme/icon-m-attention",
            "GollumEvent": "image://theme/icon-m-document",
            "MemberEvent": "image://theme/icon-m-add",
            "PublicEvent": "image://theme/icon-m-globe"
        }
        return icons[eventType] || "image://theme/icon-m-information"
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

    function refresh() {
        loading = true
        appWindow.py.call("gitwatch.github_client.get_recent_activity", [30], function(result) {
            activityModel.clear()
            for (var i = 0; i < result.length; i++) {
                var item = result[i]
                item.dateGroup = formatDateGroup(item.created_at)
                activityModel.append(item)
            }
            loading = false
        })
        appWindow.py.call("gitwatch.github_client.get_watched_users", [], function(users) {
            watchedUsers = users
        })
    }

    function checkForNew() {
        appWindow.py.call("gitwatch.github_client.run_background_check", [], function(result) {
            if (result.status === "ok" && result.count > 0) {
                notification.summary = "GitWatch"
                notification.body = result.count + " ny(e) aktivitet(er) fundet"
                notification.publish()
            }
            refresh()
        })
    }

    Component.onCompleted: {
        refresh()
    }

    Connections {
        target: appWindow
        onApplicationActiveChanged: {
            if (appWindow.applicationActive) {
                refresh()
            }
        }
    }
}
