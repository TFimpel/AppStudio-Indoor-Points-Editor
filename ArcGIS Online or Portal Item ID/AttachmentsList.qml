import QtQuick 2.3
import QtQuick.Controls 1.2
import QtQuick.Layouts 1.1
import QtPositioning 5.3
import QtQuick.Controls.Styles 1.4 //styling the search box per http://doc.qt.io/qt-5/qml-qtquick-controls-styles-textfieldstyle.html
import QtQuick.Dialogs 1.2

import ArcGIS.AppFramework 1.0
import ArcGIS.AppFramework.Controls 1.0
import ArcGIS.AppFramework.Runtime 1.0
import ArcGIS.AppFramework.Runtime.Controls 1.0

import "Helper.js" as Helper

ListView{
    clip: true
    width: parent.width
    height: parent.height
    anchors.top: attachmentsbuttongrid.bottom
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    property int itemHeight: 20
    model: attachmentsModel
    delegate: Item {
        height: attachmentsList.itemHeight * scaleFactor
        width: parent.width
        clip: true

        Rectangle{
            anchors.fill:parent
            border.color: "grey"
            border.width: 1
            color:"transparent"
            anchors.margins: 1
        }

        Text {
            text: name
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
        }

        MouseArea {
            id: itemMouseArea
            anchors.fill: parent
            onClicked: {
                attachmentsList.currentIndex = index
            }
        }
    }
    highlightFollowsCurrentItem: true
    highlight: Rectangle {
        height: attachmentsList.currentItem.height
        color: "cyan"
    }
    focus: true
    ListModel {
        id: attachmentsModel
    }

    Rectangle {
        anchors {
            fill: app
            margins: -10 * scaleFactor
        }
        visible: attachmentImage.visible
        color: "black"
        border.color: "black"
        border.width: 1
        opacity: 0.77
    }
}
