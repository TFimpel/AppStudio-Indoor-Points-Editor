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
    signal changebasemap(string name, string url)
    clip: true
    property int itemHeight: zoomButtons.width
    model: basemapModel
    delegate: basemapDelegate

    highlightFollowsCurrentItem: true
    highlight: Rectangle {
        height: basemapList.currentItem.height
        color: "cyan"
    }

    Rectangle{
        anchors.fill: parent
        color: 'transparent'
        border.color: 'blue'
        border.width: 1
    }

    Component{
        id: basemapDelegate

        Item {
            height: zoomButtons.width
            width: basemapList.width
            clip: true
            anchors.margins: 2

            Rectangle{
                anchors.fill:parent
                border.color: "darkblue"
                border.width: 1
                color:"transparent"
            }

            Text {
                text: name
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width:basemapList.width
                height: parent.height
                fontSizeMode: Text.Fit
                minimumPointSize: 6
                font.pointSize: 16
                clip:true
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment:  Text.AlignHCenter
            }

            MouseArea {
                id: baemapitemMouseArea
                anchors.fill: parent
                onClicked: {
                    if (basemapList.currentIndex != index){
                        console.log("Different basemap selected selected. " + name + ", " + url)
                        basemapList.currentIndex = index
                        changebasemap(name, url);
                    }
                    else{
                        console.log("This basemap is already selected.")
                    }
                }
            }
        }
    }
    ListModel {
        id: basemapModel
        ListElement {
            name: 'basemapname'
            url: 'basemapurl'
        }
    }
}
