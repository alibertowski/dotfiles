import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland

PopupWindow {
    id: trayWindow

    required property Item anchorItem
    required property QsMenuHandle trayMenu
    property HyprlandFocusGrab grab

    implicitWidth: 1
    implicitHeight: 1
    visible: true
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    color: "transparent"
    grab: grabb

    QsMenuOpener {
        id: menuOpener

        property int largestSize: 0

        menu: trayWindow.trayMenu
        onChildrenChanged: () => {
            trayWindow.implicitHeight = children.values.length !== 0 ? children.values.length * 20 : 1;
            for (let i = 0; i < children.values.length; i++) {
                if (children.values[i].text.length > largestSize)
                    largestSize = children.values[i].text.length;

            }
            trayWindow.implicitWidth = largestSize !== 0 ? largestSize * 9.2 : 1;
        }
    }

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

                property int largestSize: 0

                model: menuOpener.children

                Rectangle {
                    id: menuEntryBlock

                    required property QsMenuEntry modelData

                    Component.onCompleted: Log.objPrint(modelData)
                    color: "#000000"
                    implicitHeight: 20
                    implicitWidth: menuOpener.largestSize * 9.2

                    Loader {
                        active: menuEntryBlock.modelData.buttonType === QsMenuButtonType.CheckBox

                        sourceComponent: CheckBox {
                        }

                    }

                    Image {
                        id: menuEntryIcon

                        source: menuEntryBlock.modelData.icon
                        // To get the best image quality, set the image source size to the same size
                        // as the rendered image.
                        sourceSize.width: width
                        sourceSize.height: height
                        anchors.verticalCenter: menuEntryBlock.verticalCenter
                    }

                    TerminalText {
                        anchors.leftMargin: 5
                        anchors.left: menuEntryIcon.right
                        anchors.verticalCenter: menuEntryBlock.verticalCenter
                        text: menuEntryBlock.modelData.text
                        visible: !menuEntryBlock.modelData.isSeparator
                    }

                    MouseArea {
                        anchors.fill: menuEntryBlock
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        onClicked: () => {
                            if (!menuEntryBlock.modelData.isSeparator)
                                menuEntryBlock.modelData.triggered();

                            grabb.active = false;
                            grabb.cleared();
                        }
                        onEntered: () => {
                            menuEntryBlock.color = "#333333";
                        }
                        onExited: () => {
                            menuEntryBlock.color = "#000000";
                        }
                    }

                }

            }

        }

    }

}
