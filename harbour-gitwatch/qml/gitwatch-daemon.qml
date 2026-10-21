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
import io.thp.pyotherside 1.0
import Nemo.Notifications 1.0

QtObject {
    id: daemon

    property var notification: null
    property var releaseNotification: null
    property bool pythonReady: false

    Component.onCompleted: {
        notification = notificationComponent.createObject(daemon)
        releaseNotification = releaseNotificationComponent.createObject(daemon)
    }

    Component {
        id: notificationComponent
        Notification {
            appName: "harbour-gitwatch"
            appIcon: "harbour-gitwatch"
            category: "x-harbour.harbour-gitwatch.event"
        }
    }

    Component {
        id: releaseNotificationComponent
        Notification {
            appName: "harbour-gitwatch"
            appIcon: "harbour-gitwatch"
            category: "x-harbour.harbour-gitwatch.release"
        }
    }

    Python {
        id: py
        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl("../python"))
            importModule("gitwatch.github_client", function() {
                console.log("Skoða daemon: Python module loaded")
                daemon.pythonReady = true
                checkTimer.start()
            })
        }
        onError: {
            console.log("Skoða daemon Python error: " + traceback)
        }
    }

    Timer {
        id: checkTimer
        interval: 60000
        running: false
        repeat: true
        onTriggered: daemon.runCheck()
    }

    function runCheck() {
        if (!pythonReady) return

        py.call("gitwatch.github_client.are_notifications_enabled", [], function(enabled) {
            if (!enabled) return

            py.call("gitwatch.github_client.check_for_updates", [], function(newEvents) {
                if (newEvents.length === 0) return

                py.call("gitwatch.github_client.filter_events_for_notification", [newEvents], function(filtered) {
                    if (filtered.length === 0) return

                    var releaseEvents = []
                    var otherEvents = []
                    for (var i = 0; i < filtered.length; i++) {
                        if (filtered[i].type === "ReleaseEvent") {
                            releaseEvents.push(filtered[i])
                        } else {
                            otherEvents.push(filtered[i])
                        }
                    }

                    if (otherEvents.length > 0) {
                        var firstOther = otherEvents[0]
                        var otherSummary = "Skoða: " + firstOther.summary
                        var otherBody = (firstOther.user || "") + ": " + firstOther.body
                        if (otherEvents.length > 1) {
                            otherBody += " (+" + (otherEvents.length - 1) + " flere)"
                        }
                        publishNotification(notification, otherSummary, otherBody)
                    }

                    if (releaseEvents.length > 0) {
                        py.call("gitwatch.github_client.is_notification_sound_enabled", [], function(soundEnabled) {
                            var firstRelease = releaseEvents[0]
                            var releaseSummary = "Skoða: " + firstRelease.summary
                            var releaseBody = (firstRelease.user || "") + ": " + firstRelease.body
                            if (releaseEvents.length > 1) {
                                releaseBody += " (+" + (releaseEvents.length - 1) + " flere)"
                            }
                            var target = soundEnabled ? releaseNotification : notification
                            publishNotification(target, releaseSummary, releaseBody)
                        })
                    }
                })
            })
        })
    }

    function publishNotification(notif, summary, body) {
        if (!notif) return
        notif.previewSummary = summary
        notif.previewBody = body
        notif.summary = summary
        notif.body = body
        notif.publish()
    }
}
