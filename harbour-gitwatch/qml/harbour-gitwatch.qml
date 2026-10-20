import QtQuick 2.6
import Sailfish.Silica 1.0
import io.thp.pyotherside 1.5
import "pages"

ApplicationWindow {
    id: appWindow
    initialPage: Qt.resolvedUrl("pages/MainPage.qml")
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: defaultAllowedOrientations

    Python {
        id: py
        objectName: "py"

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl("../python"))
            importModule("gitwatch.github_client", function() {
                console.log("gitwatch module loaded")
            })
        }

        onError: {
            console.log("Python error: " + traceback)
        }

        function findChild(objName) {
            return py
        }
    }
}
