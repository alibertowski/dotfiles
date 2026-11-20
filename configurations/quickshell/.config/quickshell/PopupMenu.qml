import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland

PopupWindow {
    id: trayWindow

    required property Item anchorItem
    //required property Item items
    property HyprlandFocusGrab grab

    implicitWidth: 80
    implicitHeight: 60
    visible: true
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    color: '#000000'
    grab: grabb

    HyprlandFocusGrab {
        id: grabb

        active: true
        windows: [trayWindow]
    }

    MultiBorderRectangle {
        anchors.fill: parent

        Column {
            anchors.fill: parent

            Repeater {
                id: menuEntryRepeater

                model: ["poweroff", "sleep", "reboot"]
                anchors.fill: parent

                Rectangle {
                    id: entryRectangle

                    required property string modelData

                    color: '#000000'
                    implicitHeight: 20
                    implicitWidth: 80

                    TerminalText {
                        text: entryRectangle.modelData
                    }

                    MouseArea {
                        anchors.fill: entryRectangle
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        onClicked: () => {
                            console.log(entryRectangle.modelData);
                            grabb.active = false;
                            grabb.cleared();
                        }
                        onEntered: () => {
                            entryRectangle.color = "#333333";
                        }
                        onExited: () => {
                            entryRectangle.color = "#000000";
                        }
                    }

                }

            }

        }

    }

}
