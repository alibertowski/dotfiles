import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    anchors.top: true
    anchors.left: true
    margins.top: 15
    margins.left: 15
    exclusiveZone: 0
    implicitWidth: 400
    implicitHeight: 420
    WlrLayershell.namespace: "QSNotif"
    color: "transparent"

    NotificationServer {
        id: notifServer

        onNotification: (notif) => {
            notif.tracked = true;
            console.log(trackedNotifications.values.length);
        }
    }

    Column {
        spacing: 15

        Repeater {
            model: notifServer.trackedNotifications

            Item {
                id: notifItem

                required property Notification modelData

                // Give the delegate a concrete size so the Column can lay it out
                width: 400
                height: 90

                MultiBorderRectangle {
                    id: wrapRect

                    anchors.fill: parent
                    color: "transparent"
                    layer.enabled: true // This helps the ShaderEffectSource capture it

                    // 1. The Source Item
                    child: Rectangle {
                        width: notifItem.width
                        height: notifItem.height
                        color: "#cc000000"

                        IconImage {
                            id: notifIcon

                            source: notifItem.modelData.image != "" ? notifItem.modelData.image : "image://icon//home/retro/.config/quickshell/wired.gif"
                            implicitSize: 50
                            backer.anchors.leftMargin: 15
                            backer.anchors.topMargin: 15
                        }

                        Text {
                            font.family: "Hack Nerd Font Mono"
                            color: "#f4f4f4"
                            font.pointSize: 11
                            textFormat: Text.StyledText
                            anchors.top: notifIcon.top
                            anchors.topMargin: 13
                            anchors.left: notifIcon.right
                            anchors.leftMargin: 15
                            width: 350
                            wrapMode: Text.Wrap
                            text: "<b>" + notifItem.modelData.summary + "</b><br>" + notifItem.modelData.body
                        }

                    }

                }

                Timer {
                    interval: 2000
                    running: true
                    onTriggered: () => {
                        wrapRect.visible = false;
                        shadEff.visible = true;
                    }
                }

                // 3. The Shader
                ShaderEffect {
                    id: shadEff

                    // Uniforms
                    // Point to the SOURCE, not the Box
                    property variant noiseTex
                    property real fizzleAmount: 0
                    property real time: 0
                    property variant source

                    visible: false
                    anchors.fill: parent // Fills the delegate Item (400x35)
                    fragmentShader: "fizzle.frag.qsb"

                    source: ShaderEffectSource {
                        sourceItem: wrapRect
                        //live: true // Keep true if the text/source changes
                        hideSource: true
                    }

                    SequentialAnimation on fizzleAmount {
                        PauseAnimation {
                            duration: 2000
                        }

                        NumberAnimation {
                            from: 0
                            to: 0.05
                            duration: 1
                            easing.type: Easing.Linear
                        }

                    }

                    SequentialAnimation on opacity {
                        onStopped: notifItem.modelData.expire()

                        PauseAnimation {
                            duration: 2000
                        }

                        NumberAnimation {
                            from: 1 // Set running for testing
                            to: 0
                            duration: 300
                        }

                    }

                    // --- Animations ---
                    NumberAnimation on time {
                        id: timeAnim

                        from: 0 // Set running for testing
                        to: 1000
                        duration: 1000
                        loops: Animation.Infinite
                        easing.type: Easing.Linear
                    }

                }

            }

        }

    }

    mask: Region {
    }

}
