import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: root

        // WlrLayershell.namespace: "QSBar"
        required property ShellScreen modelData

        screen: modelData
        implicitWidth: screen.width
        implicitHeight: 20
        anchors.top: true
        color: "transparent"

        AnimatedImage {
            source: "/home/retro/media/images/lain/bgN6.gif"
            fillMode: Image.Tile
            anchors.fill: parent

            Row {
                spacing: 10
                anchors.right: parent.right

                TerminalText {
                    text: 'Wireguard connection'
                }

                TerminalText {
                    text: 'mpd song and controls'
                }

                TerminalText {
                    text: 'cpu usage/ram usage/VRAM/disk?'
                }

                TerminalText {
                    text: 'wifi/internet connection'
                }

                TerminalText {
                    text: 'mic in use or screen recording'
                }

                TerminalText {
                    text: 'brightness'
                }

                TerminalText {
                    text: 'battery?'
                }

                TerminalText {
                    text: 'volume?'
                }

                Repeater {
                    model: SystemTray.items

                    IconImage {
                        id: sysIcon

                        required property SystemTrayItem modelData

                        implicitSize: 20
                        source: modelData.icon

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: (mouse) => {
                                Log.objPrint(modelData);
                                if (mouse.button === Qt.LeftButton) {
                                    sysIcon.modelData.activate();
                                } else if (mouse.button === Qt.RightButton) {
                                    menuLoader.setSource("TrayMenu.qml", {
                                        "trayMenu": sysIcon.modelData.menu,
                                        "anchorItem": sysIcon
                                    });
                                } else {
                                    if (mouse.button === Qt.MiddleButton)
                                        console.log(`Button Clicked: Qt.MiddleButton`);
                                    else
                                        console.log(`Unknown button clicked: ${mouse.button}`);
                                    sysIcon.modelData.secondaryActivate();
                                }
                            }
                        }

                        Loader {
                            id: menuLoader

                            onLoaded: () => {
                                item.grab.onCleared.connect(() => {
                                    sourceComponent = undefined;
                                });
                            }
                        }

                    }

                }

            }

            Row {
                id: workspacesRow

                readonly property var kanjiNumbers: ["外", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

                spacing: 5

                TerminalText {
                    id: powerText

                    text: '󰐥 Remember to love lain.'
                    anchors.right: dateText.left

                    MouseArea {
                        // Quickshell.execDetached(['systemctl', 'suspend']);

                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onClicked: {
                            powerMenuLoader.setSource("PopupMenu.qml", {
                                "anchorItem": powerText
                            });
                        }

                        Loader {
                            id: powerMenuLoader

                            onLoaded: () => {
                                item.grab.onCleared.connect(() => {
                                    sourceComponent = undefined;
                                });
                            }
                        }

                    }

                }

                Repeater {
                    model: Hyprland.workspaces

                    TerminalText {
                        id: workspaceText

                        required property HyprlandWorkspace modelData

                        text: modelData.id > 0 && modelData.id <= 10 ? workspacesRow.kanjiNumbers[modelData.id] : workspacesRow.kanjiNumbers[0]
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            onClicked: workspaceText.modelData.activate()
                        }

                    }

                }

            }

            TerminalText {
                id: dateText

                anchors.centerIn: parent
                text: Qt.formatDateTime(clock.date, "ddd MMM d hh:mm:ss AP t yyyy")

                SystemClock {
                    id: clock

                    precision: SystemClock.Seconds
                }

            }

        }

    }

}
