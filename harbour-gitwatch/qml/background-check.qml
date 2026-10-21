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
        appName: "harbour-gitwatch"
        appIcon: "harbour-gitwatch"
        category: "gitwatch.event"
    }

    Notification {
        id: releaseNotification
        appName: "harbour-gitwatch"
        appIcon: "harbour-gitwatch"
        category: "gitwatch.release"
        sound: "default"
    }

    Python {
        id: py
        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl("../python"))
            importModule("gitwatch.github_client", function() {
                py.call("gitwatch.github_client.check_for_updates", [], function(newEvents) {
                    console.log("Background check found " + newEvents.length + " new events")
                    if (newEvents.length > 0) {
                        var releaseEvents = []
                        var otherEvents = []
                        for (var i = 0; i < newEvents.length; i++) {
                            if (newEvents[i].type === "ReleaseEvent") {
                                releaseEvents.push(newEvents[i])
                            } else {
                                otherEvents.push(newEvents[i])
                            }
                        }

                        if (otherEvents.length > 0) {
                            var firstOther = otherEvents[0]
                            notification.previewSummary = "GitWatch: " + firstOther.summary
                            notification.previewBody = (firstOther.user || "") + ": " + firstOther.body
                            notification.summary = "GitWatch: " + firstOther.summary
                            notification.body = (firstOther.user || "") + ": " + firstOther.body
                            if (otherEvents.length > 1) {
                                notification.body += " (+" + (otherEvents.length - 1) + " flere)"
                            }
                            notification.publish()
                        }

                        if (releaseEvents.length > 0) {
                            py.call("gitwatch.github_client.is_notification_sound_enabled", [], function(soundEnabled) {
                                var firstRelease = releaseEvents[0]
                                var summary = "GitWatch: " + firstRelease.summary
                                var body = (firstRelease.user || "") + ": " + firstRelease.body
                                if (releaseEvents.length > 1) {
                                    body += " (+" + (releaseEvents.length - 1) + " flere)"
                                }
                                if (soundEnabled) {
                                    releaseNotification.previewSummary = summary
                                    releaseNotification.previewBody = body
                                    releaseNotification.summary = summary
                                    releaseNotification.body = body
                                    releaseNotification.publish()
                                } else {
                                    notification.previewSummary = summary
                                    notification.previewBody = body
                                    notification.summary = summary
                                    notification.body = body
                                    notification.publish()
                                }
                                Qt.quit()
                            })
                            return
                        }
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
