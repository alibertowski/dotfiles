import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Quickshell.Widgets

Scope {
    id: root

    property bool shouldShowOsd: false

    // Bind the pipewire node so its volume will be tracked
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Connections {
        function onVolumeChanged() {
            root.shouldShowOsd = true;
            hideTimer.restart();
        }

        target: Pipewire.defaultAudioSink.audio
    }

    Timer {
        id: hideTimer

        interval: 1000
        onTriggered: root.shouldShowOsd = false
    }

    // The OSD window will be created and destroyed based on shouldShowOsd.
    // PanelWindow.visible could be set instead of using a loader, but using
    // a loader will reduce the memory overhead when the window isn't open.
    LazyLoader {
        active: root.shouldShowOsd

        PanelWindow {
            // Since the panel's screen is unset, it will be picked by the compositor
            // when the window is created. Most compositors pick the current active monitor.

            anchors.bottom: true
            margins.bottom: screen.height / 5
            exclusiveZone: 0
            implicitWidth: 400
            implicitHeight: 50
            color: "transparent"
            WlrLayershell.namespace: "QSVolumeOSD"

            MultiBorderRectangle {
                id: test

                anchors.fill: parent

                AnimatedImage {
                    source: "/home/retro/media/images/lain/Static2.gif"
                    fillMode: Image.Tile

                    TerminalText {
                        anchors.centerIn: parent
                        font.hintingPreference: Font.PreferFullHinting
                        text: {
                            let volume = Pipewire.defaultAudioSink.audio.volume ?? 0;
                            let totalBlocks = 20;
                            let filledCount = Math.floor(volume * totalBlocks);
                            let emptyCount = totalBlocks - filledCount;
                            return "VOL [" + "█".repeat(filledCount) + "░".repeat(emptyCount) + "] " + Math.round(volume * 100) + "%";
                        }
                    }

                }

            }

        }

    }

}
