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

ApplicationWindow {
    id: bgWindow
    allowedOrientations: Orientation.Portrait

    Python {
        id: py
        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl("../python"))
            importModule("gitwatch.github_client", function() {
                py.call("gitwatch.github_client.run_background_check", [], function(result) {
                    console.log("Background check result: " + JSON.stringify(result))
                    Qt.quit()
                })
            })
        }
        onError: {
            console.log("Python error: " + traceback)
            Qt.quit()
        }
    }

    Component.onCompleted: {
        // App will quit automatically after check completes
    }
}
