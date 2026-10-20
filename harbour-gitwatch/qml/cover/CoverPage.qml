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
