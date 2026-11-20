// TODO: Fix multiple monitor issue when they turn off and ons
pragma Singleton
import QtQml
import Quickshell
import Quickshell.Io

Singleton {
    // FileView {
    //     id: logFile
    //     path: Qt.resolvedUrl("./file.txt")
    // }

    function objPrint(obj) {
        let s = "========= [ " + obj.toString() + " ] ==========\n";
        for (var property in obj) {
            if (typeof obj[property] === "string")
                s += property + ": \"" + obj[property] + "\"; Type: " + typeof obj[property] + "\n";
            else if (typeof obj[property] !== "function")
                s += property + ": " + obj[property] + "; Type: " + typeof obj[property] + "\n";
        }
        console.log(s);
    }

}
