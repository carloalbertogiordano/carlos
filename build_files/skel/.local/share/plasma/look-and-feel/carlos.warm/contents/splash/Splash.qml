import QtQuick 2.15

Item {
    id: root
    property int stage

    Rectangle {
        anchors.fill: parent
        color: "#2C1810"

        Image {
            anchors.fill: parent
            source: "/usr/share/wallpapers/Nordic-mountain-wallpaper.jpg"
            fillMode: Image.PreserveAspectCrop
            smooth: true
            opacity: 0.22
        }

        // dim overlay
        Rectangle {
            anchors.fill: parent
            color: "#2C1810"
            opacity: 0.55
        }

        Column {
            anchors.centerIn: parent
            spacing: 36

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "carlos"
                font.pixelSize: 52
                font.weight: Font.Light
                font.family: "Noto Sans"
                color: "#E8D5B7"
                renderType: Text.NativeRendering
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Repeater {
                    model: 5
                    Rectangle {
                        width: 8; height: 8
                        radius: 4
                        color: root.stage > index ? "#B8753A" : "#4a3828"
                        Behavior on color {
                            ColorAnimation { duration: 200 }
                        }
                    }
                }
            }
        }
    }
}
