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


Flickable {
    anchors.top:relrecordsfieldpanebuttongrid.bottom
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    contentHeight: relTableFieldsColumn.height
    contentWidth: parent.width
    clip:true

    ColumnLayout {
        id: relTableFieldsColumn
        clip: true

        anchors {
            top:featuredetailsPaneTopbar.bottom
            left:parent.left
            right:parent.right

        }


        Repeater {

            model: relTableFieldsModel

            Row {
                id: relRow

                Label {
                    id: relNameLabel
                    text: name
                    color: "black"
                    horizontalAlignment: Text.AlignHCenter
                    width:parent.width*0.5
                }

                TextField {
                    id: relValueEdit
                    readOnly: false
                    text: string
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
