import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

Scope {
    id: root

    property bool shouldShowPowerSettings: false

    CustomShortcut {
        name: "Power"
        description: "Launches the Power Settings"
        onPressed: () => {
            console.log("oading");
            root.shouldShowPowerSettings = true;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: w

            required property ShellScreen modelData

            screen: modelData
            exclusiveZone: 0
            implicitWidth: screen.width
            implicitHeight: screen.height
            visible: root.shouldShowPowerSettings
            WlrLayershell.namespace: "QSPower"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            Loader {
                id: l

                active: root.shouldShowPowerSettings
                sourceComponent: Hyprland.focusedMonitor.name === w.modelData.name ? one : two
                onLoaded: () => {
                    w.data.push(l.item);
                }
            }

            Component {
                id: one

                Rectangle {
                    Keys.onEscapePressed: (event) => {
                        console.log('pressed');
                        root.shouldShowPowerSettings = false;
                    }
                    focus: true
                    anchors.fill: parent
                    color: '#cc000000'

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: false
                        acceptedButtons: Qt.LeftButton
                        onClicked: () => {
                            root.shouldShowPowerSettings = false;
                        }
                    }

                }

            }

            Component {
                id: two

                Rectangle {
                    anchors.fill: parent
                    color: 'transparent'
                    layer.enabled: true

                    AnimatedImage {
                        source: "/home/retro/media/images/lain/bgN6.gif"
                        fillMode: Image.Tile
                        anchors.fill: parent
                        smooth: false
                    }

                    TerminalText {
                        anchors.centerIn: parent
                        text: "Let's all love lain."
                    }

                    AnimatedImage {
                        source: "assets/insomnia.gif"
                        fillMode: Image.PreserveAspectFit
                        smooth: false
                        width: 1000
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                    }

                    layer.effect: ShaderEffect {
                        // Uniforms
                        // Point to the SOURCE, not the Box
                        property real fizzleAmount: 0.006
                        property real time: 0

                        fragmentShader: "fizzle.frag.qsb"

                        // --- Animations ---
                        NumberAnimation on time {
                            from: 0 // Set running for testing
                            to: 100
                            duration: 100000
                            loops: Animation.Infinite
                            easing.type: Easing.Linear
                        }

                    }

                }

            }

        }

    }

}
