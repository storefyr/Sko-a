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
