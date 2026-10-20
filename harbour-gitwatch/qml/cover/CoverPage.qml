import QtQuick 2.6
import Sailfish.Silica 1.0

CoverBackground {
    id: cover

    property int newCount: 0

    Column {
        anchors {
            top: parent.top
            topMargin: Theme.paddingLarge
            horizontalCenter: parent.horizontalCenter
        }
        spacing: Theme.paddingSmall

        Image {
            source: "/usr/share/icons/hicolor/86x86/apps/harbour-gitwatch.png"
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Label {
            text: "GitWatch"
            color: Theme.primaryColor
            font.pixelSize: Theme.fontSizeMedium
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Label {
            text: newCount > 0 ? newCount + " ny aktivitet" : "Ingen nyt"
            color: Theme.secondaryColor
            font.pixelSize: Theme.fontSizeSmall
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    CoverActionList {
        CoverAction {
            iconSource: "image://theme/icon-cover-refresh"
            onTriggered: {
                appWindow.py.call("gitwatch.github_client.run_background_check", [], function(result) {
                    if (result.status === "ok") {
                        cover.newCount = result.count || 0
                    }
                })
            }
        }
    }
}
