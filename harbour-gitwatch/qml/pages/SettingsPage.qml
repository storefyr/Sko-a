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

Page {
    id: settingsPage
    allowedOrientations: defaultAllowedOrientations

    property var watchedUsers: []
    property bool notificationsEnabled: true

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
                        remorseAction("Fjern " + modelData + "?", function() {
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

            SectionHeader {
                text: "Om"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: "GitWatch 0.2.2\nOvervåger GitHub-aktivitet for udvalgte brugere.\nTjekker hver 30. minut i baggrunden."
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

    Component.onCompleted: {
        loadUsers()
        appWindow.py.call("gitwatch.github_client.are_notifications_enabled", [], function(enabled) {
            notificationsEnabled = enabled
            notifSwitch.checked = enabled
        })
    }

    Connections {
        target: appWindow
        onWatchedUsersChanged: loadUsers()
    }
}
