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
    anchors.top: relrecordsbuttongrid.bottom
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    delegate: relrecordslistdelegate
    model: relrecordslistmodel

    highlight: Rectangle {
        height: relRecordsList.currentItem.height
        color: "cyan"
    }
    focus: true

    ListModel {
        id: relrecordslistmodel
        ListElement {
            relTableListView_titlefield1Value: ""
            object_id: ""
            relTable_fkFieldVaue: ""
            relTableListView_titlefield2Value: ""
        }
    }
    Component {
        id: relrecordslistdelegate
        Item {
            width: parent.width
            height: infobutton.width
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle{
                anchors.fill:parent
                border.color: "grey"
                border.width: 1
                color:"transparent"
                anchors.margins: 1
            }

            Column {

                Text {text: relTableListView_titlefield1 + ': ' + relTableListView_titlefield1Value}
                Text { text: relTableListView_titlefield2 + ': ' + relTableListView_titlefield2Value}
                anchors.margins: 3
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                clip: true
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    relRecordsList.currentIndex = index
                }
            }
        }
    }
}
