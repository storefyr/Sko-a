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
                text: "GitWatch 0.1.0\nOvervåger GitHub-aktivitet for udvalgte brugere.\nTjekker hver 30. minut i baggrunden."
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }
        }

        VerticalScrollDecorator {}
    }

    function addUser() {
        var username = newUserField.text.trim()
        if (username.length === 0) return
        appWindow.py.call("gitwatch.github_client.add_watched_user", [username], function(users) {
            watchedUsers = users
            newUserField.text = ""
        })
    }

    Component.onCompleted: {
        appWindow.py.call("gitwatch.github_client.get_watched_users", [], function(users) {
            watchedUsers = users
        })
        appWindow.py.call("gitwatch.github_client.are_notifications_enabled", [], function(enabled) {
            notificationsEnabled = enabled
            notifSwitch.checked = enabled
        })
    }
}
