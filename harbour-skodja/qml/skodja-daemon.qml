/****************************************************************************************
 * harbour-skodja - GitHub Activity Notifier for Sailfish OS
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

QtObject {
    id: daemon

    property bool pythonReady: false

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
        py.call("gitwatch.github_client.check_and_notify", [], function(result) {
            if (result && result.status === "ok" && result.notified > 0) {
                console.log("Skoða daemon: Published " + result.notified + " notification(s) via D-Bus")
            } else if (result && result.status === "error") {
                console.log("Skoða daemon error: " + result.error)
            }
        })
    }
}
