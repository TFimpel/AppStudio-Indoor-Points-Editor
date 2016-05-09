import QtQuick 2.0
import QtQuick.Controls 1.2
import QtQuick.Controls.Styles 1.3

ComboBoxStyle {
    textColor :"Black"
    renderType: Text.QtRendering

    background: Rectangle {
        color: "white"
        radius: 2
        border.color: "black"
        border.width: 1
        height: parent.height

        Image {
            id: imageArrow
            source: "images/blackArrow.png"
            rotation: 180
            visible: true
            width: height

            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
                margins: 3 * app.scaleFactor
            }
            fillMode: Image.PreserveAspectFit
        }
    }

    label: Text {
        id: labelText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        width:  parent.width
        color: "Black"
        text: control.currentText
    }
    selectedTextColor: "Black"
    selectionColor: 'cyan'
}
