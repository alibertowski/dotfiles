import QtQuick
import Quickshell.Widgets

Rectangle {
    id: p

    // color: '#ffffff'
    // innerColor: '#000000'
    // leftColor: '#ff0000'
    // rightColor: '#00ff00'
    // topColor: '#0000ff'
    // bottomColor: '#ffff00'
    // leftSize: 5
    // rightSize: 5
    // bottomSize: 5
    // topSize: 5
    // innerSize: 5
    property color topColor: '#e9e9e9'
    property color bottomColor: '#616162'
    property color leftColor: '#e9e9e9'
    property color rightColor: '#616162'
    property real topSize: 1
    property real bottomSize: 1
    property real leftSize: 1
    property real rightSize: 1
    property real innerSize: 1
    property color innerColor: '#c9c9c9'
    default property alias child: buffer.data

    color: 'transparent'

    Item {
        id: buffer

        anchors.fill: p

        MarginWrapperManager {
            topMargin: p.topSize + p.innerSize
            bottomMargin: p.bottomSize + p.innerSize
            leftMargin: p.leftSize + p.innerSize
            rightMargin: p.rightSize + p.innerSize
        }

    }

    // Outer borders
    Rectangle {
        id: topBorder

        anchors.top: p.top
        anchors.left: p.left
        anchors.right: p.right
        color: p.topColor
        height: p.topSize
    }

    Rectangle {
        id: bottomBorder

        anchors.bottom: p.bottom
        anchors.left: p.left
        anchors.right: p.right
        color: p.bottomColor
        height: p.bottomSize
    }

    Rectangle {
        id: leftBorder

        anchors.left: p.left
        anchors.top: p.top
        anchors.bottom: bottomBorder.top
        color: p.leftColor
        width: p.leftSize
    }

    Rectangle {
        id: rightBorder

        anchors.right: p.right
        anchors.top: p.top
        anchors.bottom: p.bottom
        color: p.rightColor
        width: p.rightSize
    }

    // Inner borders
    Rectangle {
        anchors.top: topBorder.bottom
        anchors.left: leftBorder.right
        anchors.right: rightBorder.left
        color: p.innerColor
        height: p.innerSize
    }

    Rectangle {
        anchors.bottom: bottomBorder.top
        anchors.left: leftBorder.right
        anchors.right: rightBorder.left
        color: p.innerColor
        height: p.innerSize
    }

    Rectangle {
        anchors.left: leftBorder.right
        anchors.top: topBorder.bottom
        anchors.bottom: bottomBorder.top
        color: p.innerColor
        width: p.innerSize
    }

    Rectangle {
        anchors.right: rightBorder.left
        anchors.top: topBorder.bottom
        anchors.bottom: bottomBorder.top
        color: p.innerColor
        width: p.innerSize
    }

}
