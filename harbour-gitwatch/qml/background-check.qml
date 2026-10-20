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

import QtQuick 2.0
import Sailfish.Silica 1.0
import io.thp.pyotherside 1.0
import Nemo.Notifications 1.0

ApplicationWindow {
    id: bgWindow
    allowedOrientations: Orientation.Portrait

    Notification {
        id: notification
        appName: "GitWatch"
        appIcon: "harbour-gitwatch"
        category: "gitwatch.event"
    }

    Python {
        id: py
        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl("../python"))
            importModule("gitwatch.github_client", function() {
                py.call("gitwatch.github_client.check_for_updates", [], function(newEvents) {
                    console.log("Background check found " + newEvents.length + " new events")
                    if (newEvents.length > 0) {
                        var firstEvent = newEvents[0]
                        notification.summary = firstEvent.summary
                        notification.body = (firstEvent.user || "") + ": " + firstEvent.body
                        if (newEvents.length > 1) {
                            notification.body += " (+" + (newEvents.length - 1) + " flere)"
                        }
                        notification.publish()
                    }
                    Qt.quit()
                })
            })
        }
        onError: {
            console.log("Python error: " + traceback)
            Qt.quit()
        }
    }
}
