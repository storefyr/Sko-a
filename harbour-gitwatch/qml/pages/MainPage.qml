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
    property string lastCheck: ""

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

        delegate: ListItem {
            id: delegate
            contentHeight: Theme.itemSizeMedium

            Column {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.paddingSmall

                Row {
                    spacing: Theme.paddingSmall
                    width: parent.width

                    Label {
                        text: model.summary
                        color: delegate.highlighted ? Theme.highlightColor : Theme.primaryColor
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                        width: parent.width - timeLabel.width - parent.spacing
                        truncationMode: TruncationMode.Fade
                    }

                    Label {
                        id: timeLabel
                        text: formatTime(model.created_at)
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }

                Label {
                    text: model.user + " · " + model.repo
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                }

                Label {
                    text: model.body
                    color: delegate.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    maximumLineCount: 1
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

    function formatTime(isoString) {
        if (!isoString) return ""
        var date = new Date(isoString)
        var now = new Date()
        var diff = now - date
        var minutes = Math.floor(diff / 60000)
        var hours = Math.floor(diff / 3600000)
        var days = Math.floor(diff / 86400000)

        if (minutes < 1) return "lige nu"
        if (minutes < 60) return minutes + " min siden"
        if (hours < 24) return hours + " t siden"
        if (days < 7) return days + " dage siden"
        return date.toLocaleDateString("da-DK")
    }

    function refresh() {
        loading = true
        appWindow.py.call("gitwatch.github_client.get_recent_activity", [30], function(result) {
            activityModel.clear()
            for (var i = 0; i < result.length; i++) {
                activityModel.append(result[i])
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
