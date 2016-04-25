//------------------------------------------------------------------------------
//IMPORT MODULES AND JAVASCRIPT FILE
import QtMultimedia 5.3
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
//-----------------------------------------------------------------------------
App {
    id: app
    width: 300
    height: 500

    //----------------------------------------------------------------------------------------------
    //AUTHENTICATION MECHANISM BEGIN
    property string authUrl
    property bool signedInToPortal: false

    //for starting in offline for 30days add code per https://doc.arcgis.com/en/appstudio/extend-apps/licenceyourapp.htm
    LicenseInfo{
        id: licenseinfo
    }

    Portal {
        id: portal
        url: app.info.propertyValue("Portal or ArcGIS Online URL","http://umn.maps.arcgis.com")
        credentials: oAuthCredentials

        Component.onCompleted: {
            signIn();
        }
        onSignInComplete: {
            console.log(qsTr("Signed in! Now setting the appstudio license level."));
            var myUsername = oAuthCredentials.userName //used for displaying username on welcomescreen
            ArcGISRuntime.license.setLicense(portal.portalInfo.licenseInfo)

            if (ArcGISRuntime.license.licenseLevel === Enums.LicenseLevelBasic) {
                console.log("basic")
                singInButtonText.text = "Signed in as " + myUsername + "<br>License level:  basic - You can view but not edit features."

            } else if (ArcGISRuntime.license.licenseLevel === Enums.LicenseLevelStandard) {
                console.log("standard")
                singInButtonText.text = "Signed in as " + myUsername + "<br>License level:  standard - You can view and edit features"

            } else if (ArcGISRuntime.license.licenseLevel === Enums.LicenseLevelDeveloper) {
                console.log("developer")
                singInButtonText.text = "Signed in as " + myUsername + "<br>License level: developer - You can view and edit features"
            }
         }
    }

    UserCredentials {
        id: oAuthCredentials
        oAuthClientInfo: OAuthClientInfo {
            clientId: app.info.propertyValue("clientId","8lFrEYanAZFe8kuF") //make this a regular configurable app parameter. reading it from appinfo  doesn't seem to work
            oAuthMode: Enums.OAuthModeUser
        }
    }

    Connections {
        target: ArcGISRuntime.identityManager

        onOAuthCodeRequired: {
            authUrl = authorizationUrl;
            console.log(authUrl) //ArcGIS Online/Portal Instance to authenticate to
            webViewContainer.webView.url = authorizationUrl;
        }
    }

    WebViewContainer {
        id: webViewContainer
        anchors.fill: parent //QML WebViewContainer needs to take up full screen. It doesn't work well otherwise.
        visible: if (visiblePane == 'webviewcontainer'){true}else{false}
    }

    Connections {
        target: webViewContainer.webView

        onLoadingChanged: {
            console.log("webView.title", webViewContainer.webView.title);

            if (webViewContainer.webView.title.indexOf("SUCCESS code=") > -1) {
                var authCode = webViewContainer.webView.title.replace("SUCCESS code=", "");
                ArcGISRuntime.identityManager.setOAuthCodeForUrl(authUrl, authCode);
                ArcGISRuntime.license.setLicense(portal.portalInfo.licenseInfo) //per https://doc.arcgis.com/en/appstudio/extend-apps/licenceyourapp.htm
                signedInToPortal = true; //variable to block subsequent sign in requests whie app is running
                visiblePane = 'welcomemenucontainer' //once signed in return to the welcome screen

                //once signed in get the feature service information.
                serviceInfoTask.fetchFeatureServiceInfo();
                serviceInfoTask2.fetchFeatureServiceInfo();

            } else if (webViewContainer.webView.title === "Denied error=access_denied") {
                console.log("User denied request")
                visiblePane = 'welcomemenucontainer'  // Cancel pressed, return to the welcome screen. But will need to restart app to sign in again.
            }
        }
    }
    //AUTHENTICATION STUFF END
    //--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    //BEGIN INITIALIZING SOME GLOBAL VARIABLES

    //points layer fields and their associated dropdownlists. Will be derived from attribute fields when .geodatabase is created, or if already preset when app load completed.
    property var pointslayerfieldswithdropdowns_json: JSON.parse("{}")

    //related table fields and their associated dropdownlists/  Will be derived from attribute fields when .geodatabase is created, or if already preset when app load completed.
    property var reltablefieldswithdropdowns_json: JSON.parse("{}")

    //helps in dealing with different device screen resolutions.
    property real scaleFactor: AppFramework.displayScaleFactor

    //used for determining whether point/related table/attachment information is displayed below the map or besides the map
    property bool isLandscape : width > height

    //used for determining which of the main "screens" is visible.
    property string visiblePane: 'welcomemenucontainer' //can take values 'cameracontainer','mapcontainer', 'welcomemenucontainer', 'webviewcontainer', 'searchmenucontainer' .

    //used for determining how the screen portion that shows point/related table/attacment information is show (or not shown)
    property string sideOrBottomPaneContainerState: 'closed'     //can take values 'closed', 'expanded', 'minimized'


    //variables that keep track of current feature selections and editing modes
    property var editedFeatureID:''
    property var editedFeatureRelateKeyValue: ''
    property var editedRelatedFeatureID:''
    property string editingMode: 'none'     //can take on values 'none', 'attr', 'geom' , 'del', 'ins'
    property string relRecordEditingOperation: 'none' //can take 'Update', 'Insert', 'Delete' , 'none'
    property string attachmenteditingMode: 'none' //can take on values 'none', 'del'

    //function to effectively 'reset' selections, models, visible elements, etc. Used for example when all features are de-selected
    function clearSelectionsAndAssociatedModels(){
        console.log('running clearSelectionsAndAssociatedModels')

        //close the feature details container. and hide it's contents
        sideOrBottomPaneContainerState = 'closed'
        attachmentsPane.visible = false
        relatedRecordsPane.visible = false
        relatedRecordFieldPane.visible = false
        featureDetailsPane.visible = false

        //set global variables that keep track of selections to initial state
        editedFeatureID = ''
        editedFeatureRelateKeyValue = ''
        editedRelatedFeatureID = ''
        editingMode = 'none'
        relRecordEditingOperation = 'none'
        attachmenteditingMode = 'none'

        //clear models that hold data from current selections
        attachmentsList.model.clear();
        pointslistview.model.clear();
        fieldsModel.clear();
        relRecordsList.model.clear();
        relTableFieldsModel.clear();
        localPointsLayer.selectFeaturesByIds(0,false) //unselect point currently highlighted on map
    }

    //used for determining which of the search "screens" is visible in the search menu
    property string searchmode: 'buildingsearchmode' //can be 'buildingsearchmode', 'roomsearchmode' , or 'pointsearchmode'. default is 'buildingsearchmode'.

    //the floor value of the point or room that was searched, or of the point that was selected from the pointslistview
    property string searchFloorID: ''

    //variables to enable the points layer to be 'floor-aware'. Only tested with fields of type string.
    property string pointsLyr_floorIdField: app.info.propertyValue("pointsLyr_floorIdField","Floor")
    property string pointsLyr_bldgIdField: app.info.propertyValue("pointsLyr_bldgIdField","Building")

    //the field that the points layer can be search on via the search screen
    property string pointsLyr_searchField: app.info.propertyValue("pointsLyr_searchField","Asset_ID")

    //The path to the .tpk file once downloaded. Used to read its created data via FileInfo class as well as in basemap picker.
    property string tpkfilepath: ""

    //variable to hold the currently selected building, by ObjectID.
    property var currentBuildingObjectID: ""
    //variable to hold the currently selected building, by building id.
    property var currentBuildingID: ""

    //a list of buildings for search menu. List is built when searchmenu is opened.
    property var allBlgdList: []

    //a list of rooms for search menu. List is built when searchmenu is opened the first time.
    property var allRoomsList: []

    //a list of points for search menu. List is built when point search is opened.
    property var allPointsList: []

    //define relevant field names, used in many ways (example: associate floors with buildings, autogenerate floor and building value when new point is inserted)
    property string bldgLyr_nameField: app.info.propertyValue("Buildings layer building name field","NAME")
    property string bldgLyr_bldgIdField: app.info.propertyValue("Buildings layer building ID field","BUILDING_NUMBER")

    property string lineLyr_bldgIdField: app.info.propertyValue("Floor plan lines layer building ID field","BUILDING")
    property string lineLyr_floorIdField: app.info.propertyValue("Floor plan lines layer floor field","FLOOR")
    property string lineLyr_sortField: app.info.propertyValue("Floor plan lines layer sort field","FLOOR")

    property string roomLyr_bldgIdField: app.info.propertyValue("Floor plan polygon layer building ID field","BUILDING")
    property string roomLyr_floorIdField: app.info.propertyValue("Floor plan polygon layer floor field","FLOOR")
    property string roomLyr_roomIdField: app.info.propertyValue("Floor plan polygon layer room field","RMNUMB")

    //define which attribute fields to hide for points layer. note at this point no spaces!
    property string pointsLyr_hideFields: app.info.propertyValue("pointsLyr_hideFields", "OBJECTID,GlobalID")

    //define which attribute fields to hide for the related table. note at this point no spaces!
    property string relTable_hideFields: app.info.propertyValue("relTable_hideFields", "OBJECTID,GlobalID,Rel_Global_ID")

    //define primary and foreign keys in points Lyr and related table. (note that this completely ignores relationship class functionality. Many to many relationships n theory possible, but never actually tested.)
    property string relTable_fkField: app.info.propertyValue("relTable_fkField", "Rel_Global_ID")
    property string pointsLyr_fkField: app.info.propertyValue("pointsLyr_fkField", "GlobalID")

    //define which 2 attributes to show in the pointslist ListView
    property string pointsListView_titlefield1: app.info.propertyValue("pointsListView_titlefield1", "Asset_ID")
    property string pointsListView_titlefield2: app.info.propertyValue("pointsListView_titlefield2", "Manufacturer")

    //define which 2 attributes to show in the relrecordslist ListView
    property string relTableListView_titlefield1: app.info.propertyValue("relTableListView_titlefield1", "Workorder_ID")
    property string relTableListView_titlefield2: app.info.propertyValue("relTableListView_titlefield2", "Workorder_Type")

    //define 3 online basemap choices (addtl. to local .tpk). Note that if ESRI basemaps are used ESRI needs to be credited.
    property string basemap1_name: app.info.propertyValue("basemap1_name", "   Topography   ")
    property string basemap1_url: app.info.propertyValue("basemap1_url","http://services.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer")

    property string basemap2_name: app.info.propertyValue("basemap2_name","   Satellite   ")
    property string basemap2_url: app.info.propertyValue("basemap2_url","http://services.arcgisonline.com/arcgis/rest/services/World_Imagery/MapServer")

    property string basemap3_name:app.info.propertyValue("basemap3_name","    Streets    ")
    property string basemap3_url: app.info.propertyValue("basemap3_url","http://services.arcgisonline.com/arcgis/rest/services/World_Street_Map/MapServer")


    //END INITIALIZING SOME GENERAL GLOBAL VARIABLES
    //--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    //BEGIN SECTION ON DEVICE CAMERA SETUP AND ADD ATTACHMENT MECHANISM

        //this is used for retrieving attachments.
        FileFolder {
            id: tempFolder
        }

        //this is used for adding atachments from camera. While app is running cameraState is alwys active.
        //That could definitely be improved to save battery power.
        Camera {
            id: camera
            //cameraState: videoOutput.visible ? Camera.ActiveState : Camera.UnloadedState //should work but leads to error that camera is not ready for capture.
            cameraState: Camera.ActiveState

            imageCapture {
                resolution: Qt.size(288, 432) //...going with resolution used in esri samples.
                onImageSaved: {
                    visiblePane = 'mapcontainer'
                    console.log("Camera image path changed: ", camera.imageCapture.capturedImagePath);
                    var geodatabaseAttachment = ArcGISRuntime.createObject("GeodatabaseAttachment");
                    if (geodatabaseAttachment.loadFromFile(camera.imageCapture.capturedImagePath, "application/octet-stream")){
                        localPointsTable.addAttachment(editedFeatureID, geodatabaseAttachment);
                        console.log("Loading the GeodatabaseAttachment.")
                    }
                    else{
                        console.log("Failed to load the GeodatabaseAttachment.")
                    }
                }
            }
        }
        //fill almost all of the screen with what the camera sees.
        Rectangle {
            anchors {
                fill: videoOutput
                margins: -10 * scaleFactor
            }
            visible: videoOutput.visible
            color: "black"
            radius: 5
            border.color: "black"
            opacity: 0.77
        }

        VideoOutput {
            id: videoOutput
            visible: if (visiblePane == 'cameracontainer'){true}else{false}
            anchors.fill: parent
            anchors.margins: 20 * scaleFactor
            source: camera
            focus : visible
            autoOrientation: true

            MouseArea {
                anchors.fill: parent
                onClicked: mouse.accepted = true
            }

            //in the lower left of the screen place a "Capture Image" and a "Cancel" button.
            Rectangle {
                anchors {
                    fill: imageCaptureControlsColumn
                    margins: -10 * scaleFactor
                }
                color: "lightgrey"
                radius: 5
                border.color: "black"
                opacity: 0.77
                visible: if (visiblePane == 'cameracontainer'){true}else{false}
            }

            Column {
                id: imageCaptureControlsColumn
                anchors {
                    left: parent.left
                    bottom: parent.bottom
                    margins: 20 * scaleFactor
                }
                spacing: 10 * scaleFactor

                Button {
                    text: "Capture Image"
                    onClicked: {
                        camera.imageCapture.capture()
                        sideOrBottomPaneContainerState = 'expanded'
                        visiblePane = 'mapcontainer'
                    }
                }

                Button {
                    text: "Cancel"
                    onClicked: visiblePane = 'mapcontainer' //closing the camera brings you back to mapcontainer
                }
            }
        }
    //END SECTION ON DEVICE CAMERA SETUP AND ADD ATTACHMENT MECHANISM
    //--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    //BEGIN DOWNOAD AND SYNC MECHANISM SETUP

    //General note: download mechanisms are very similar for floor plans feature service and points layer feature service.
    //example: variable "gdbPath" is for buildings and floor plans feature service, and "gdbPath2" is for the points layer
    //feature service. This pattern of appending the character "2" is carried on throughout many parts fo the application.

    property string appItemId: app.info.itemId

    //Define place to store local geodatabases.
    //Store in .../Apps/appItemId/... so that if app is removed all data is removed as well.
    property string gdbPath: "~/ArcGIS/AppStudio/Apps/" + appItemId + "/Data/gdb.geodatabase"
    property string gdbPath2: "~/ArcGIS/AppStudio/Apps/" + appItemId + "/Data2/gdb2.geodatabase"

    //one file per .geodatabase that is used to track when .geodatabase was last synced lasat. This file is updated when a sync
    //operation has completed successfully. Then we read the file's last modified date to know when the last sync occured.
    property string syncLogFolderPath: "~/ArcGIS/AppStudio/Apps/" + appItemId + "/Data"
    property string syncLogFolderPath2: "~/ArcGIS/AppStudio/Apps/" + appItemId + "/Data2"
    property string updatesCheckfilePath: "~/ArcGIS/AppStudio/Apps/" + appItemId + "/Data/syncLog.txt"
    property string updatesCheckfilePath2: "~/ArcGIS/AppStudio/Apps/" + appItemId + "/Data2/syncLog2.txt"

    //two file that are used to track whether .geodatabase files should be deleted when app is reopened.
    //A bit awkward, but the only thing that seems to work (see https://geonet.esri.com/message/570264?et=watches.email.thread#570264)
    property string nextTimeDeleteGDBfilePath: "~/ArcGIS/AppStudio/Apps/" + appItemId + "/Data/nextTimeDeleteGDB.txt"
    property string nextTimeDeleteGDBfilePath2: "~/ArcGIS/AppStudio/Apps/" + appItemId + "/Data2/nextTimeDeleteGDB2.txt"

    //the secured feature services from which the .geodatabase will replicated.
    //featuresUrl2 should have one points layer with geodatabase attachments enabled and one geodatabase table, associated by a 1:M relationship class.
    property string featuresUrl: app.info.propertyValue("Floor Plans and Buildings Feature Service URL","http://services.arcgis.com/8df8p0NlLFEShl0r/arcgis/rest/services/WestBankFloors_April2016/FeatureServer")
    property string featuresUrl2:  app.info.propertyValue("featuresUrl2","http://services.arcgis.com/8df8p0NlLFEShl0r/arcgis/rest/services/WIFI_DEMODATA/FeatureServer")

    //stores the extent of the tile package once it is downloaded. used as extent for generating and syncing offline geodatabases by means of always setting the map's extent to this when welcomemenuscreen is shown
    property var tpkExtent: ""

    //use these files to keep track of whether the floor plans .geodatabase shuld be deleted next time app is opened
    FileInfo {
        id: nextTimeDeleteGDBfile
        filePath: nextTimeDeleteGDBfilePath
    }
    FileInfo {
        id: nextTimeDeleteGDBfile2
        filePath: nextTimeDeleteGDBfilePath2
    }

    //the .geodatabase with the building and floor plan layers
    FileInfo {
        id: gdbfile
        //if to be deleted from device then set path to "null" to avoid file locking
        filePath: if (nextTimeDeleteGDBfile.exists == true){"null"} else {gdbPath}

        function generategdb(){
            generateGeodatabaseParameters.initialize(serviceInfoTask.featureServiceInfo);

            //the tpk extent is used to determine the .geodatabase extent
            generateGeodatabaseParameters.extent = map.extent;
            generateGeodatabaseParameters.returnAttachments = false;
            geodatabaseSyncTask.generateGeodatabase(generateGeodatabaseParameters, gdbPath);
            gdbinfobuttontext.text = " Downloading updates now. Please wait until complete. This may take some time. "
        }

        function syncgdb(){
            gdb.path = gdbPath //if this is not set then function fails with "QFileInfo::absolutePath: Constructed with empty filename" message.
            gdbinfobuttontext.text = " Downloading updates now. Please wait until complete. This may take some time. "
            console.log(JSON.stringify(gdb.syncGeodatabaseParameters.json))
            geodatabaseSyncTask.syncGeodatabase(gdb.syncGeodatabaseParameters, gdb);
        }
    }

    //eh .geodatbase with the point layer and table
    FileInfo {
        id: gdbfile2
        //if to be deleted from device then set path to "null" to avoid file locking
        filePath: if (nextTimeDeleteGDBfile2.exists == true){"null"} else {gdbPath2}

        function generategdb(){
            generateGeodatabaseParameters2.initialize(serviceInfoTask2.featureServiceInfo);
            //the tpk extent is used to determine the .geodatabase extent
            generateGeodatabaseParameters2.extent = map.extent;
            generateGeodatabaseParameters2.returnAttachments = true;
            generateGeodatabaseParameters2.layerIds = [0,1] //get the point layer as well as the related table
            geodatabaseSyncTask2.generateGeodatabase(generateGeodatabaseParameters2, gdbPath2);
            gdbinfobuttontext2.text = " Downloading updates now. Please wait until complete. This may take some time. "
        }

        function syncgdb(){
            gdb2.path = gdbPath2 //if this is not set then function fails with "QFileInfo::absolutePath: Constructed with empty filename" message.
            gdbinfobuttontext2.text = " Downloading updates now...this may take some time. "
            gdb2.syncGeodatabaseParameters.layerIds = [0,1] //sync the point layer as well as the related table
            geodatabaseSyncTask2.syncGeodatabase(gdb2.syncGeodatabaseParameters, gdb2);
            console.log(JSON.stringify(gdb2.syncGeodatabaseParameters.json))
            gdbinfobuttontext2.text = " Downloading updates now. Please wait until complete. This may take some time. "
        }
    }

    //use these files to keep track of when the app has synced last
    FileInfo {
        id: updatesCheckfile
        filePath: updatesCheckfilePath
    }
    FileInfo {
        id: updatesCheckfile2
        filePath: updatesCheckfilePath2
    }

    //referenced by a variety of housekeeping tasks (not only sync-logging, in retrosect the name is misleading)
    FileFolder{
        id:syncLogFolder
        path: syncLogFolderPath
    }
    FileFolder{
        id:syncLogFolder2
        path: syncLogFolderPath2
    }

    //reference to feature services from which to generate the builidng/floor .geodatabases
    ServiceInfoTask{
        id: serviceInfoTask
        url: featuresUrl
        credentials: oAuthCredentials

        onFeatureServiceInfoStatusChanged: {
            if (featureServiceInfoStatus === Enums.FeatureServiceInfoStatusCompleted) {
                console.log("serviceInfoTask emitted signal FeatureServiceInfoStatusCompleted")
                //once user is authenticated successfully to all feature services rearrange the user interface
                Helper.doorkeeper()
                gdbinfoimagebutton.enabled = true //enable the downoad/sync button
                tpkinfocontainer.update()
                gdbinfocontainer.update()
                proceedbuttoncontainer.update()
            }
        }
    }

    ServiceInfoTask{
        id: serviceInfoTask2
        url: featuresUrl2
        credentials: oAuthCredentials

        onFeatureServiceInfoStatusChanged: {
            if (featureServiceInfoStatus === Enums.FeatureServiceInfoStatusCompleted) {
                console.log("serviceInfoTask2 emitted signal FeatureServiceInfoStatusCompleted")
                //once user authenticated successfully to feature service rearrange the user interface
                Helper.doorkeeper()
                gdbinfoimagebutton2.enabled = true //enable the downoad/sync button
                tpkinfocontainer.update()
                gdbinfocontainer2.update()
                proceedbuttoncontainer.update()
            }
        }
    }

    GenerateGeodatabaseParameters {
        id: generateGeodatabaseParameters
    }

    GenerateGeodatabaseParameters {
        id: generateGeodatabaseParameters2
        layerIds: [0,1] //not configuable at this point
        returnAttachments: true
    }

    GeodatabaseSyncStatusInfo {
        id: syncStatusInfo
    }

    GeodatabaseSyncStatusInfo {
        id: syncStatusInfo2
    }

    GeodatabaseSyncTask {
        id: geodatabaseSyncTask
        url: featuresUrl
        credentials: oAuthCredentials

        onGenerateStatusChanged: {
            if (generateStatus === Enums.GenerateStatusInProgress) {
                gdbinfobuttontext.text = " Downloading updates in progress...this may take some time. "
                busyindicator.running = true
            } else if (generateStatus === Enums.GenerateStatusCompleted) {
                console.log("Finished generating local .geodatabase for buildings/floors.")
                busyindicator.running = false

                //re-assing proceedbuttoncontainermousearea.enabled property. I don't know why but I keep needing to re-assing this for it to behave correctly.
                gdbfile.refresh()
                proceedbuttoncontainermousearea.enabled = (tpkfile.exists==true && gdbfile.exists==true && gdbfile2.exists==true) ? true : false

                gdbfile.syncgdb();//a workaround. can only get layers to shown up in map after a sync. not after initial generate only.
            } else if (generateStatus === GeodatabaseSyncTask.GenerateError) {
                busyindicator.running = false
                console.log("Generate GDB Error: " + generateGeodatabaseError.message + " Code= "  + generateGeodatabaseError.code.toString() + " "  + generateGeodatabaseError.details)
                gdbinfobuttontext.text = "Generate GDB Error: " + generateGeodatabaseError.message + " Code= "  + generateGeodatabaseError.code.toString() + " "  + generateGeodatabaseError.details + "  Make sure you have internet connectivity and are signed in. ";
            }
        }

        onSyncStatusChanged: {
            if (syncStatus === Enums.SyncStatusInProgress){
                gdbinfobuttontext.text = " Syncing updates in progress...this may take some time. "
                busyindicator.running = true
            }
            if (syncStatus === Enums.SyncStatusCompleted) {
                busyindicator.running = false
                //create the file that keeps track of when last synced
                Helper.writeSyncLog()
                gdbinfobuttontext.text = "Downloading/Syncing updates completed"
                Helper.doorkeeper()
                gdbDeleteButton.enabled = true //setting this property to listen for gdbfile.exists is buggy. Just set to true.
            }
            if (syncStatus === Enums.SyncStatusErrored){
                busyindicator.running = false
                console.log("Sync GDB Error: " + syncGeodatabaseError.message + " Code= "  + syncGeodatabaseError.code.toString() + " "  + syncGeodatabaseError.details)
                gdbinfobuttontext.text = "Sync GDB Error: " + syncGeodatabaseError.message + " Code= "  + syncGeodatabaseError.code.toString() + " "  + syncGeodatabaseError.details + "  Make sure you have internet connectivity and are signed in. " ;
            }
        }
    }
    GeodatabaseSyncTask {
        id: geodatabaseSyncTask2
        url: featuresUrl2
        credentials: oAuthCredentials

        onGenerateStatusChanged: {
            if (generateStatus === Enums.GenerateStatusInProgress) {
                busyindicator.running = true
                gdbinfobuttontext2.text = " Downloading updates in progress...this may take some time. "
            } else if (generateStatus === Enums.GenerateStatusCompleted) {
                console.log("Finished generating local .geodatabase for points/table.")
                busyindicator.running = false

                //re-assing proceedbuttoncontainermousearea.enabled property. I don't know why but I keep needing to re-assing this for it to behave correctly.
                gdbfile2.refresh()
                proceedbuttoncontainermousearea.enabled = (tpkfile.exists==true && gdbfile.exists==true && gdbfile2.exists==true) ? true : false

                gdbfile2.syncgdb(); //a workaround. can only get layers to shown up in map after sync. not after initial generate.
            } else if (generateStatus === GeodatabaseSyncTask.GenerateError) {
                busyindicator.running = false
                gdbinfobuttontext2.text = "Generate GDB Error: " + generateGeodatabaseError.message + " Code= "  + generateGeodatabaseError.code.toString() + " "  + generateGeodatabaseError.details + "  Make sure you have internet connectivity and are signed in. ";
            }
        }
        onSyncStatusChanged: {
            if(syncStatus === Enums.SyncStatusInProgress){
                gdbinfobuttontext2.text = " Syncing updates in progress...this may take some time. "
                busyindicator.running = true
            }
            if (syncStatus === Enums.SyncStatusCompleted) {
                busyindicator.running = false
                //create file that keeps track of when last synced
                console.log('synctask2 completed successfully')
                Helper.writeSyncLog2()
                gdbinfobuttontext2.text = "Downloading/Syncing updates completed"
                Helper.doorkeeper()
                gdbDeleteButton2.enabled = true //settig this property to watch for gdbfile2.exists is buggy
                //rebuild drop down lists from attribute's coded value domains bbecasue they may have change since last sync.
                Helper.detectcodedvaluedomains (localPointsTable,  pointslayerfieldswithdropdowns_json)
                Helper.detectcodedvaluedomains (localRelRecordsTable,  reltablefieldswithdropdowns_json)
            }
            if (syncStatus === Enums.SyncStatusErrored){
                busyindicator.running = false
                gdbinfobuttontext2.text = "Sync GDB2 Error: " + syncGeodatabaseError.message + " Code= "  + syncGeodatabaseError.code.toString() + " "  + syncGeodatabaseError.details + "  Make sure you have internet connectivity and are signed in. " ;
            }
        }
    }
    //set up components for operational map layers: buildings, room-polygons, lines
    Geodatabase {
        id: gdb
        //set path to "null" initially. once app is loaded we set this path properly.
        //this is done to avoid file locking. applying if/else depending on whether the
        //gdbdeletefile exists doesn't work here for some reason.
        path: "null"
        //syncGeodatabaseParameters.syncDirection: 'SyncDirectionDownload' // this doesn't have the expected effect. the sync operation still seems to attempt to upload changes (even if there are zero changes) and an error is reported. to avoid the error message you need to set the feature layer properties to allow uploads
    }

    Geodatabase {
        id: gdb2
        path: "null" //why? see note above for gdb
    }

    GeodatabaseFeatureTable {
        id: localLinesTable
        geodatabase: gdb.valid ? gdb : null
        featureServiceLayerId: app.info.propertyValue("Floorplan Lines LayerID","")

        onQueryFeaturesStatusChanged: {
            //this is used to build the floor list.
            //assumption is that there is one row per building-floor in this layer
            if (queryFeaturesStatus === Enums.QueryFeaturesStatusCompleted) {
                Helper.populateFloorListView(queryFeaturesResult.iterator, currentBuildingID , lineLyr_sortField)
            }
        }
    }

    GeodatabaseFeatureTable {
        id: localRoomsTable
        geodatabase: gdb.valid ? gdb : null
        featureServiceLayerId: app.info.propertyValue("Floorplan Polygons LayerID","")

        onQueryFeaturesStatusChanged: {
            //this is used to build the room search list. This can take a long time to complete
            //if you have many rooms. Needs improvement.
            if (queryFeaturesStatus == Enums.QueryFeaturesStatusInProgress){
                busyindicator.running = true
            }
            if (queryFeaturesStatus === Enums.QueryFeaturesStatusCompleted) {
                Helper.buildAllRoomsList(queryFeaturesResult.iterator)
            }
        }
    }

    GeodatabaseFeatureTable {
        id: localBuildingsTable
        geodatabase: gdb.valid ? gdb : null
        featureServiceLayerId: app.info.propertyValue("Building Polygons LayerID","")

        onQueryFeaturesStatusChanged: {
            //this is used to build the building search list
            //assumption is that there is one row per building in this layer
            if (queryFeaturesStatus === Enums.QueryFeaturesStatusCompleted) {
                console.log('buildAllBlgdList')
                Helper.buildAllBlgdList(queryFeaturesResult.iterator)
            }
        }
    }

    GeodatabaseFeatureTable {
        id: localPointsTable
        geodatabase: gdb2.valid ? gdb2 : null
        featureServiceLayerId: 0 //not configurable at this point

        onQueryFeaturesStatusChanged: {
            //this is used to build the points features list in the sideOrBottomPane and in the search screen
            //if the query is run from the search menu return all the points to load into the search screen.
            //if the query is run from the map then only return the points that actually have been clicked-on.
            if (queryFeaturesStatus === Enums.QueryFeaturesStatusCompleted) {
                if (searchmode === 'pointsearchmode'){
                    console.log('points table queried from searchmenu')
                    Helper.buildAllPointsList(queryFeaturesResult.iterator)
                }
                else{
                    console.log('points table queried from map')
                    Helper.buildSelectedPointsList(queryFeaturesResult.iterator)
                }
            }
        }

        onQueryAttachmentInfosStatusChanged: {
            console.log(' onQueryAttachmentInfosStatusChanged:')
            if (localPointsLayer.featureTable.queryAttachmentInfosStatus === Enums.QueryAttachmentInfosStatusCompleted) {
                attachmentsList.model.clear()
                var count = 0;
                for (var attachmentInfo in localPointsLayer.featureTable.attachmentInfos) {
                    var info = localPointsLayer.featureTable.attachmentInfos[attachmentInfo];
                    attachmentsList.model.insert(count,
                                                 {
                                                     "attachmentId": info["attachmentId"],
                                                     "contentType": info["contentType"],
                                                     "name": info["name"],
                                                     "size": info["size"]
                                                 })
                }
                //by default highlight the top attachment in the list
                if (attachmentsList.count > 0)
                    attachmentsList.currentIndex = 0;
                count++;
            }
        }

        onRetrieveAttachmentStatusChanged: {
            if (retrieveAttachmentStatus === Enums.RetrieveAttachmentStatusCompleted) {
                if (retrieveAttachmentResult !== null) {
                    if (retrieveAttachmentResult !== null) {
                        if (Qt.platform.os === "windows") {
                            var tempPath = tempFolder.path.split(":")[1];
                            var str = retrieveAttachmentResult.saveToFile("file://" + tempPath, true);
                            attachmentImage.source = "file://" + str.split(":")[1];
                        } else {
                            var str2 = retrieveAttachmentResult.saveToFile("file://" + tempFolder.path, true);
                            attachmentImage.source = "file://" + str2;
                        }
                    }
                }
            } else if (retrieveAttachmentStatus === Enums.RetrieveAttachmentStatusErrored) {
                 editfeedbackmessage.text = "Retrieve Attachment error: " + retrieveAttachmentError
            }
        }

        onDeleteAttachmentStatusChanged: {
            if (deleteAttachmentStatus === Enums.AttachmentEditStatusCompleted) {
                editfeedbackmessage.text = "Attachment deleted successfully."
                localPointsTable.queryAttachmentInfos(editedFeatureID); //rebuild the attachments list to not show the deleted one
            } else if (deleteAttachmentStatus === Enums.AttachmentEditStatusErrored) {
                editfeedbackmessage.text = "Attachment delete failed: " + deleteAttachmentResult.error.description
            }
        }

        onAddAttachmentStatusChanged: {
            if(addAttachmentStatus == Enums.AttachmentEditStatusCompleted){
                editfeedbackmessage.text = "Attachment added successfully."
                attachmentsList.model.clear();
                localPointsLayer.featureTable.queryAttachmentInfos(editedFeatureID); //rebuild the attachments list to show the newly added one
            }
            if(addAttachmentStatus == Enums.AttachmentEditStatusErrored){
                editfeedbackmessage.text = "Adding attachment failed: " + addAttachmentResult.error.description
            }
        }
    }

    GeodatabaseFeatureTable {
        id: localRelRecordsTable
        geodatabase: gdb2.valid ? gdb2 : null
        featureServiceLayerId: 1 //not configurable at this point
        onQueryFeaturesStatusChanged: {
            //this is used to build the related records features list
            if (queryFeaturesStatus === Enums.QueryFeaturesStatusCompleted) {
                Helper.buildSelectedRelRecordsList(queryFeaturesResult.iterator)
            }
        }
    }

    //define place to store local tile package and define FileFolder object
    property string tpkItemId : app.info.propertyValue("Basemap Tile Package Item ID","52ccbba6ef9f40248d4156a8dcc80dd2");

    //used for nextTimeDeleteTPKfile, which if present on app start causes the app to delete the tile package. Just like wit the local
    //geodatabases this is oen to void file locking issues.
    FileInfo {
        id: nextTimeDeleteTPKfile
        filePath: "~/ArcGIS/AppStudio/Data/" + tpkItemId + "/nextTimeDeleteTPKfile.txt"
    }

    //the folder that contains the basemap tile package file
    FileFolder {
        id: tpkFolder
        //currently not possible to save in .../Apps/appItemId/... folderName (see https://geonet.esri.com/message/544407#544407 )
        path: "~/ArcGIS/AppStudio/Data/" + tpkItemId

        function addLayer(){
            var filesList = tpkFolder.fileNames("*.tpk");
            var newLayer = ArcGISRuntime.createObject("ArcGISLocalTiledLayer");
            var newFilePath = tpkFolder.path + "/" + filesList[0];
            newLayer.path = newFilePath;

            //Set the map's fullExtent and extentto the .tpk's extent so that when offline gedatabases
            //are generated only the features that are in the map extent are downloaded
            tpkExtent = newLayer.fullExtent
            map.extent = tpkExtent

            //add to groupLayer.
            groupLayer.add(newLayer,0);

            //add tpk layer to basemap List
            tpkfilepath = newFilePath; //assign to a global variable that is picked up by the function that sets the bae map list

            map.refresh();

            //reassign this to make sure it updates as needed
            tpkfile.refresh()
            proceedbuttoncontainermousearea.enabled = (tpkfile.exists==true && gdbfile.exists==true && gdbfile2.exists==true) ? true : false
        }

        function downloadThenAddLayer(){
            downloadTpk.download(tpkItemId);
        }
    }
    //instantiate FileInfo to read last modified date of tpk.
    FileInfo{
        id: tpkfile
        filePath: tpkfilepath
    }


    //Declare ItemPackage for downloading tile package
    ItemPackage {
        id: downloadTpk
        onDownloadStarted: {
            tpkinfobuttontext.text = "Download starting... 0%"
            busyindicator.running = true
        }
        onDownloadProgress: {
            tpkinfobuttontext.text = "Download in progress... " + percentage +"%"
        }
        onDownloadComplete: {
            console.log('Tile package finished downloading to ' + tpkFolder.path)
            busyindicator.running = false
            tpkFolder.addLayer();
            Helper.doorkeeper();
        }
        onDownloadError: {
            busyindicator.running = false
            tpkinfobuttontext.text = "Download failed"
            Helper.doorkeeper();
        }
    }

    //END DOWNLOAD AND SYNC MECHANISM SETUP
    //--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    //--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    //BEGIN MAP AND ON-MAP COMPONENTS

    //this is the bar that is always present along the top of the app
    Rectangle{
        id: topbar
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width:parent.width
        height: zoomButtons.width * 1.4
        color: "darkblue"

        StyleButtonNoFader{
            id: welcomemenu
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 2
            visible: if (visiblePane == 'welcomemenucontainer' | visiblePane == 'searchmenucontainer'){false}else{true} //hide this button when you are already on the welcomemenu screen
            iconSource: "images/actions.png"
            backgroundColor: "transparent"
            hoveredColor: "#0000b3"
            onClicked: {
                map.extent = tpkExtent //set this for generate and sync full extent
                proceedtomaptext.text  = "Go to Map"
                visiblePane = 'welcomemenucontainer'
                clearSelectionsAndAssociatedModels(); //hides sideOrBottomPaneContainer and clears current selected features etc.
                Helper.doorkeeper()
            }
        }
        Text{
            id:titletext
            text: if(searchmenucontainer.visible == true){"     Search Menu     "}else{app.info.propertyValue("App Title","Floor Plan Viewer")}
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            height:parent.height
            width: parent.width - height * 2
            fontSizeMode: Text.Fit
            minimumPixelSize: 10
            font.pixelSize: 72
            clip:true
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment:  Text.AlignHCenter
            color:"white"
            font.weight: Font.DemiBold
        }

        StyleButtonNoFader {
            id: searchmenu
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 2
            visible: {if (visiblePane == 'mapcontainer' || visiblePane == 'searchmenucontainer'){true}else{false}} //ony show search buttn when you're on mapscreen
            iconSource: if (searchmenucontainer.visible === true){"images/close.png"} else{"images/search.png"}
            backgroundColor: "transparent"
            hoveredColor: "#0000b3"
            onClicked: {
                clearSelectionsAndAssociatedModels();
                //if your'e in search screen already then clicking this button brings you back to map screen
                if (visiblePane == 'searchmenucontainer'){
                    visiblePane = 'mapcontainer';
                    searchmode = 'buildingsearchmode' //set this back to the default
                }
                //else if you are in map screen then clicking this button brings you to the search screen
                else if (visiblePane == 'mapcontainer'){
                    Helper.reloadFullBldgListModel()//builds the list used for building search
                    if (allRoomsList.length === 0){
                        Helper.getAllRooms()//builds the list used for room search. Test if the list is already built becasue it can take long to build it.
                    }
                    visiblePane = 'searchmenucontainer'
                }
            }
        }
    }

    //this is the rectangle below the topbar that holds the map and all the buttons that are on top of the map
    Rectangle{
        id: mapcontainer
        clip: true
        width: if (isLandscape){if (sideOrBottomPaneContainerState == 'closed'){parent.width} if (sideOrBottomPaneContainerState == 'expanded'){parent.width * 0.5} if (sideOrBottomPaneContainerState == 'minimized'){parent.width - sideOrBottomPaneMinimizeButton.width}}else{if (sideOrBottomPaneContainerState == 'closed'){parent.width} if (sideOrBottomPaneContainerState == 'expanded'){parent.width} if (sideOrBottomPaneContainerState == 'minimized'){parent.width}}
        height: if (isLandscape){if (sideOrBottomPaneContainerState == 'closed'){parent.height - topbar.height} if (sideOrBottomPaneContainerState == 'expanded'){parent.height - topbar.height} if (sideOrBottomPaneContainerState == 'minimized'){parent.height - topbar.height}}else{if (sideOrBottomPaneContainerState == 'closed'){parent.height - topbar.height} if (sideOrBottomPaneContainerState == 'expanded'){(parent.height * 0.5) - topbar.height} if (sideOrBottomPaneContainerState == 'minimized'){parent.height- topbar.height - sideOrBottomPaneMinimizeButton.height}}
        anchors.top: topbar.bottom
        visible: if(visiblePane === 'mapcontainer'){true}else{false}

        Map{
            id: map
            anchors.top: parent.top
            anchors.bottom: mapcontainer.bottom
            anchors.left: mapcontainer.left
            anchors.right: mapcontainer.right
            focus: true
            rotationByPinchingEnabled: true
            positionDisplay {
                positionSource: PositionSource {
                }
            }

            StyleButton {
                id: basemaptogglebutton
                iconSource: "images/basemap_control.png"
                width: zoomButtons.width
                height: width
                anchors.bottom: northarrowbackgroundbutton.top
                anchors.left: parent.left
                anchors.margins: app.height * 0.01
                anchors.bottomMargin: 2
                onClicked: {
                    basemapList.visible = !basemapList.visible //this creates toggle-ability of button
                }
            }

            BasemapList{
                id: basemapList
                anchors.left: basemaptogglebutton.right
                anchors.top: basemaptogglebutton.bottom
                anchors.margins: app.height * 0.01
                anchors.topMargin: 0
                anchors.right: floorcontainer.left
                height: zoomButtons.width * basemapList.model.count
                visible: false
                z: 999

                //This signal is emitted when a new basemap has been slected in BasemapList
                onChangebasemap: {
                    basemapList.visible = false
                    console.log("Received from BasemapList.qml: ", name, url);

                    //if default tpk is selected just remove the basemap that's sitting on top of it
                    if (url == tpkfilepath){
                        groupLayer.removeLayerByIndex(1)
                    }
                    //if basemap other than default tpk is selected set it on top of the tpk basemap
                    else{
                        if (groupLayer.layers.length > 1){groupLayer.removeLayerByIndex(1)}
                        var layer = ArcGISRuntime.createObject("ArcGISTiledMapServiceLayer");
                        layer.url = url;
                        layer.name = name;
                        layer.initialize();
                        groupLayer.add(layer,1);
                    }
                }
            }

            Rectangle{
                id: basemaplisttitlebar
                color: "darkblue"
                anchors.top:basemaptogglebutton.top
                anchors.left: basemapList.left
                width: basemapList.width
                height: zoomButtons.width
                visible: basemapList.visible
                z: basemapList.z
                Text{
                    id:basemaplistitletext
                    text: "Pick a Basemap";
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.top: parent.top
                    anchors.margins: app.height * 0.01
                    height: zoomButtons.width
                    fontSizeMode: Text.Fit
                    minimumPointSize: 12
                    font.pointSize: 18
                    clip:true
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment:  Text.AlignHCenter
                    color:"white"
                    visible: basemapList.visible
                    font.weight: Font.DemiBold
                }

            }
            Rectangle{
                id: basemaplistbackground
                color: 'white'
                anchors.fill: basemapList
                visible: basemapList.visible
                z: basemapList.z - 1
            }

            StyleButtonNoFader {
                id: infobutton
                iconSource: "images/info1.png"
                width: zoomButtons.width
                height: width
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.margins: app.height * 0.01
                anchors.bottomMargin: 2
                onClicked: {
                    infocontainer.visible = true
                    infotext.text = "See floor levels via double-click or press-and-hold on buildig polygons. Select points by tap or click. Add a new point via the marker button to the right."
                }
            }

            ZoomButtons {
                id: zoomButtons //note that a lot of elements reference this element's height and width.
                anchors.left: parent.left
                anchors.bottom: infobutton.top
                anchors.margins: app.height * 0.01
            }

            StyleButton {
                id: buttonRotateCounterClockwise
                iconSource: "images/rotate_clockwise.png"
                width: zoomButtons.width
                height: width
                anchors.bottom: zoomButtons.top
                anchors.left: zoomButtons.left
                anchors.bottomMargin: 2
                opacity: zoomButtons.opacity
                onClicked: {
                    map.mapRotation -= 22.5;
                    fader.start();
                }
            }

            StyleButton{
                id: northarrowbackgroundbutton
                anchors {
                    right: buttonRotateCounterClockwise.right
                    bottom: buttonRotateCounterClockwise.top
                }
                visible: map.mapRotation != 0
            }

            NorthArrow{
                width: northarrowbackgroundbutton.width - 4
                height: northarrowbackgroundbutton.height - 4
                anchors {
                    horizontalCenter: northarrowbackgroundbutton.horizontalCenter
                    verticalCenter: northarrowbackgroundbutton.verticalCenter
                }
                visible: map.mapRotation != 0
            }

            //this is the conatiner and list view that displays the floor levels of the selected building
            Rectangle{
                id:floorcontainer
                width: zoomButtons.width
                anchors.bottom: zoomButtons.bottom
                anchors.right: map.right
                anchors.margins: app.height * 0.01
                height: ((floorListView.count * width) > (mapcontainer.height - zoomButtons.width*1.5)) ? (mapcontainer.height - zoomButtons.width*1.5)  :  (floorListView.count * width)
                color: zoomButtons.borderColor
                border.color: zoomButtons.borderColor
                border.width: 1
                visible: false

                ListView{
                    id:floorListView
                    anchors.fill: parent
                    model:floorListModel
                    delegate:floorListDelegate
                    verticalLayoutDirection : ListView.BottomToTop
                    highlight:
                        Rectangle {
                        color: "transparent";
                        radius: 4;
                        border.color: "blue";
                        border.width: 5;
                        z : 98;}
                    focus: true
                    clip:true
                    visible: parent

                }

                ListModel {
                    id:floorListModel
                    ListElement {
                        Floor: ""
                    }

                }
                Component {
                    id: floorListDelegate
                    Item {
                        width: zoomButtons.width
                        height: width
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle{
                            anchors.fill:parent
                            border.color: zoomButtons.borderColor
                            color:zoomButtons.backgroundColor
                            anchors.margins: 1
                        }

                        Column {
                            Text { text: Floor}
                            anchors.centerIn:parent
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                floorListView.currentIndex = index;
                                Helper.setFloorFilters(index);
                            }
                        }
                    }
                }
            }

            //this is the area at the bottom of the map that dislays the building name and id when a building is selected
            //when both buttons that are enabled for adding new points are viible then the size of this area shrinks a bit.
            Rectangle{
                id:infocontainer
                height: infobutton.height
                anchors.left: infobutton.left
                anchors.right: if (editingMode == 'ins'){cancelNewPointButton.left} else{newPointButton.left}
                anchors.top: infobutton.top
                anchors.rightMargin: app.height * 0.01
                color: infobutton.backgroundColor
                border.color: infobutton.borderColor
                radius: 4
                clip: true

                Row{
                    id:inforow
                    height: parent.height - 2
                    width: parent.width - 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    StyleButtonNoFader {
                        id:closeinfobutton
                        height:parent.height
                        width: height
                        iconSource: "images/close.png"
                        borderColor: infobutton.backgroundColor
                        focusBorderColor: infobutton.backgroundColor
                        hoveredColor: infobutton.backgroundColor
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            infocontainer.visible = false
                            floorcontainer.visible = false
                            currentBuildingObjectID = ""
                            currentBuildingID = ""
                            localBuildingsLayer.clearSelection();
                            Helper.hideAllFloors();
                        }
                    }
                    Text{
                        id: infotext
                        text: "See floor levels via double-click or press-and-hold on buildig polygons. Select points by tap or click. Add a new point via the marker button to the right."
                        color: "black"
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        fontSizeMode: Text.Fit
                        minimumPointSize: 6
                        font.pointSize: 14
                        clip:true
                        width: if (zoomtoinfobutton.visible == false){infocontainer.width - closeinfobutton.width - 4}else{infocontainer.width - closeinfobutton.width - zoomtoinfobutton.width - 4}
                        anchors.top: closeinfobutton.top
                        anchors.bottom: closeinfobutton.bottom
                        verticalAlignment: Text.AlignTop
                    }

                    //zooming to the extent of the polygon doesn't always work as expected. Sometimes it zooms in too far. It's an Esri bug.
                    StyleButtonNoFader{
                        id: zoomtoinfobutton
                        height:parent.height
                        width: height
                        iconSource: "images/zoomTo.png"
                        borderColor: infobutton.backgroundColor
                        focusBorderColor: infobutton.backgroundColor
                        hoveredColor: infobutton.backgroundColor
                        anchors.verticalCenter: parent.verticalCenter
                        visible: if (currentBuildingObjectID == ""){false} else {true}
                        onClicked: {
                            console.log(currentBuildingObjectID)
                            map.zoomTo(localBuildingsLayer.featureTable.feature(currentBuildingObjectID).geometry)
                        }
                    }
                }
            }

            StyleButtonNoFader{
                id: cancelNewPointButton
                anchors.verticalCenter: infobutton.verticalCenter
                anchors.right: newPointButton.left
                anchors.margins: app.height * 0.01
                height: infobutton.height
                width: infobutton.width
                color: infobutton.backgroundColor
                borderColor: infobutton.borderColor
                visible: if (editingMode =='ins'){true}else{false}
                enabled: if (editingMode =='ins'){true}else{false}
                iconSource: "images/deletered.png"
                onClicked: {
                    editingMode = 'none'
                    clearSelectionsAndAssociatedModels();
                    console.log('Cancelled process of adding new point. Setting editingMode to "none".')
                }
            }
            StyleButtonNoFader{
                id: newPointButton
                anchors.verticalCenter: infobutton.verticalCenter
                anchors.right: map.right
                anchors.margins: app.height * 0.01
                height: infobutton.height
                width: infobutton.width
                color: infobutton.backgroundColor
                borderColor: infobutton.borderColor
                iconSource: if (editingMode == 'ins'){"images/tick.png"} else{"images/pin_star_grey.png"}
                onClicked: {
                    if(editingMode == 'ins'){
                        clearSelectionsAndAssociatedModels();
                        console.log('add new feature button cicked second time time. adding point. note that we are noe leveraginf feature templates.')

                        //if buiding and floor level are defined when in inseted then write the curent bldg and floor vaues into the points layer attriutr fields.
                        if (floorListModel.count > 0){
                            var bldg = currentBuildingID
                            var floor = floorListModel.get(floorListView.currentIndex).Floor
                        }
                        else{
                            var bldg = ''
                            var floor = ''
                        }
                        //currently only support web mercator coordinate system.
                        var featureJson = {
                            attributes:{
                            },
                            geometry:{
                                spatialReference:{
                                    "latestWkid":3857,
                                    "wkid":102100
                                },
                                x: map.extent.center.x,
                                y: map.extent.center.y
                            }
                        }

                        featureJson.attributes[pointsLyr_bldgIdField] = bldg;
                        featureJson.attributes[pointsLyr_floorIdField] = floor;

                        localPointsLayer.featureTable.addFeature(featureJson)

                        editingMode = 'none'
                    }
                    else{
                        console.log('add new feature button cicked first time. app is now in insert-mode.')
                        clearSelectionsAndAssociatedModels()
                        editingMode = 'ins'
                    }
                }
            }

            //this is the image that indicates where the new point is added in x,y space. It's always the center of the map.
            Image {
                id: pin
                source: "images/pin_center_star_orange.png"
                width: 64
                height: 64
                visible: if (editingMode == 'ins' | editingMode=='geom') {true} else {false}
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }

            }

            //when a room is selected in the search menu this callout is shown briefly and displays the room number
            Image {
                id: roomsearchcallout
                source: "images/callout.png"
                width: 64*scaleFactor
                height: 64*scaleFactor
                visible: false
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }
                NumberAnimation on opacity {
                    id: createAnimation
                    from: 1
                    to: 0.5
                    duration: 4000
                    easing.type: Easing.InCubic
                }
                onOpacityChanged: if (opacity < 0.7){visible=false}


                Text{
                    id:  roomsearchcallouttext
                    anchors.right: parent.right
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 2
                    height: parent.height /3
                    fontSizeMode: Text.Fit
                    minimumPointSize: 4
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment:  Text.AlignHCenter
                }
            }

            //this is a message that confirms the success or failure of an edit. Currently it works only on edits of the attachments
            //because the feature or table edits don't emit a similar signal that can be used for this.
            Rectangle{
                id: editfeedbackmessagebackground
                anchors.fill: editfeedbackmessage
                color: "white"
                border.color: "grey"
                border.width: 1
                visible: editfeedbackmessage.visible
            }
            Text{
                id:  editfeedbackmessage
                anchors.horizontalCenter: map.horizontalCenter
                anchors.top: map.verticalCenter
                anchors.margins: 4
                width: map.width * 0.5
                fontSizeMode: Text.Fit
                minimumPointSize: 6
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment:  Text.AlignHCenter
                color: 'black'
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                text: ""
                visible: false
                onTextChanged: {
                    visible = true
                    editfeedbackanimation.start()
                }
                NumberAnimation on opacity {
                    id: editfeedbackanimation
                    from: 1
                    to: 0.5
                    duration: 7000
                    easing.type: Easing.InCubic
                }
                onOpacityChanged: if (opacity < 0.7){
                                      visible=false
                                      editfeedbackmessage.text = "" //to avoid issue in case same message sould show twice in a row the onChange event never fires becuase the text doesn't change
                                  }
            }


            //Putting the basemap(s) in a grouplayer --> quicker to empty and add to.
            GroupLayer {
                id: groupLayer
            }

            //this is the buildings layer that when double-clicked or pressed-and-held triggers the creation of the floor list.
            //using onMousePressAndHold and onMouseDoubleClicked here allows us to use simple onMousePressed for thepoints layer and ot get them mixed up
            //better use experience when points are located within the building polygon
            FeatureLayer {
                id: localBuildingsLayer
                featureTable: localBuildingsTable
                selectionColor: "white"
                enableLabels: true
            }

            onMousePressAndHold: {
                Helper.selectBuildingOnMap(mouse.x, mouse.y);
            }
            onMouseDoubleClicked:{
                Helper.selectBuildingOnMap(mouse.x, mouse.y);
            }


            FeatureLayer {
                id: localRoomsLayer
                featureTable: localRoomsTable
                definitionExpression: "OBJECTID < 0" //hide features until floor selection is made
                enableLabels: true
                selectionColor: 'yellow'
            }

            FeatureLayer {
                id: localLinesLayer
                featureTable: localLinesTable
                definitionExpression: "OBJECTID < 0" //hide features until floor selection is made
                enableLabels: true
            }
            FeatureLayer {
                id: localPointsLayer
                featureTable: localPointsTable
                selectionColor: "cyan"
            }


            //event handler to query point features
            Query {
                id: baseQuery
                returnGeometry: true
            }
            //event handler to query records from the table
            Query{
                id: relQuery
                returnGeometry: false
            }

            //when the map is pressed look for near point features
            onMousePressed: {
                var tolerance = Qt.platform.os === "ios" || Qt.platform.os === "android" ? 10 : 1;
                var features = localPointsLayer.findFeatures(mouse.x, mouse.y, tolerance * scaleFactor, 100)
                if (features.length > 0 && editingMode != 'ins'){ //if in the process of adding a new feature disable selecting point features
                    clearSelectionsAndAssociatedModels()
                    Helper.actOnSelectPoints(features)
                };
            }
        }
    }

    //END MAP AND ON-MAP COMPONENTS
    //--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    //BEGIN SIDE OR BOTTOM PANEL THT DISPAYS ATTRIBUTES AND BUTTONS TO INTERACT WITH THE POINTS LAYER, ATTACHMENTS, AND TABLE
    Rectangle{
        id: sideOrBottomPaneContainer
        color: "white"
        border.color: "darkblue"
        border.width: 1
        width: if (isLandscape) {if (sideOrBottomPaneContainerState=='expanded'){parent.width * 0.5} if (sideOrBottomPaneContainerState=='minimized'){sideOrBottomPaneMinimizeButton.width} if (sideOrBottomPaneContainerState=='closed'){0}} else {if (sideOrBottomPaneContainerState=='expanded'){parent.width} if (sideOrBottomPaneContainerState=='minimized'){parent.width} if (sideOrBottomPaneContainerState=='closed'){0}}
        height: if (isLandscape) {if (sideOrBottomPaneContainerState=='expanded'){parent.height} if (sideOrBottomPaneContainerState=='minimized'){parent.height} if (sideOrBottomPaneContainerState=='closed'){0}} else {if (sideOrBottomPaneContainerState=='expanded'){parent.height * 0.5} if (sideOrBottomPaneContainerState=='minimized'){sideOrBottomPaneMinimizeButton.height} if (sideOrBottomPaneContainerState=='closed'){0}}
        anchors.bottom: app.bottom
        anchors.right: app.right
        anchors.left: if (isLandscape) {mapcontainer.right} else {app.left}
        anchors.top: if (isLandscape) {mapcontainer.top} else {mapcontainer.bottom}
        visible: if (visiblePane === 'mapcontainer'){true}else{false}

        Rectangle{
            id: sideOrBottomPaneTopbar
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width:parent.width
            height: zoomButtons.width
            color: "darkblue"

            StyleButtonNoFader {
                id: sideOrBottomPaneMinimizeButton
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: height
                anchors.margins: 2
                hoveredColor: "#0000b3"
                iconSource: {if (isLandscape)
                    {if(sideOrBottomPaneContainerState == 'expanded'){'images/right.png'}else{'images/left.png'}}
                    else
                    {if(sideOrBottomPaneContainerState == 'expanded'){'images/down.png'}else{'images/up.png'}}
                }
                backgroundColor: "darkblue"
                onClicked: {if(sideOrBottomPaneContainerState == 'expanded'){
                        console.log(sideOrBottomPaneContainerState)
                        sideOrBottomPaneContainerState = 'minimized'
                        console.log(sideOrBottomPaneContainerState)
                    }
                    else {sideOrBottomPaneContainerState = 'expanded'}}
            }

            Text{
                id:sideOrBottomPaneTitletext
                text: {
                    if (attachmentsPane.visible){
                        "     Attachments     "
                    }
                    else if (relatedRecordsPane.visible){
                        "   Related Records   "
                    }
                    else if (relRecordsList.visible){
                        "Related Record Details"
                    }
                    else if  (featureDetailsPane.visible){
                        "Point Feature Details "
                    }
                    else{
                        "    Point Features    "
                    }
                }

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: app.height * 0.01
                height:parent.height
                width: parent.width - parent.height * 2
                fontSizeMode: Text.Fit
                minimumPointSize: 6
                clip:true
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment:  Text.AlignHCenter
                color:"white"
                visible: if (isLandscape && sideOrBottomPaneContainerState != 'expanded'){false} else{true}
            }

            StyleButtonNoFader {
                id: sideOrBottomPaneCloseButton
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 2
                iconSource: "images/close.png"
                backgroundColor: "darkblue"
                width: height
                hoveredColor: "#0000b3"
                visible: if (sideOrBottomPaneContainerState =='expanded'){true} else{false}
                onClicked:{
                    clearSelectionsAndAssociatedModels();
                }
            }
        }

        //the listview that shows selected points features in the side panel
        ListView{
            id: pointslistview
            clip: true
            width: parent.width
            height: parent.height
            anchors.top: sideOrBottomPaneTopbar.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            model: pointslistmodel
            delegate: pointslistdelegate
            highlight: Rectangle {
                height: pointslistview.currentItem.height
                color: "cyan"
            }
            focus: true

            ListModel {
                id: pointslistmodel
                ListElement {
                    object_id: ""
                    pointsLyr_fkFieldValue: ""
                    pointsListView_titlefield1Value: ""
                    pointsListView_titlefield2Value: ""
                    pointsListView_bldgValue:""
                    pointsListView_floorValue:""
                }
            }

            Component {
                id: pointslistdelegate
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
                        Text { text: pointsListView_titlefield1 + ': '+  pointsListView_titlefield1Value }
                        Text  { text: pointsListView_titlefield2 + ': '+  pointsListView_titlefield2Value }
                        Text {text: pointsListView_bldgValue; visible: false}  //needed to make appropriate floor visible when selected
                        Text {text: pointsListView_floorValue; visible: false} //needed to make appropriate floor visible when selected

                        anchors.margins: 3
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true
                    }
                    //if you click on a listed feature show the details pane with that feature's attribute values and show the appropriate floor
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            pointslistview.currentIndex = index
                            editedFeatureID = pointslistmodel.get(index).object_id
                            editedFeatureRelateKeyValue = pointslistmodel.get(index).pointsLyr_fkFieldValue
                            Helper.getFields(localPointsLayer , editedFeatureID);
                            featureDetailsPane.visible = true;
                            localPointsLayer.selectFeaturesByIds(editedFeatureID, false)

                            //this sets the definition query so that the correct building
                            // and floor is shown, and selects the point
                            searchFloorID = pointsListView_floorValue //used so correct floor can be displayed
                            var pointBldgValue = pointslistmodel.get(index).pointsListView_bldgValue
                            var pointFloorValue = pointslistmodel.get(index).pointsListView_floorValue
                            Helper.updateroomsdisplay(pointsListView_bldgValue, pointsListView_floorValue );
                            Helper.setFloorLitIndexAfterSearch(pointsListView_floorValue)
                        }
                    }
                }
            }
        }

        //this model is for the point feature attribute names and values
        ListModel {
            id: fieldsModel
        }

        //on this rectangle points feature attributes are displayed
        Rectangle{
            id: featureDetailsPane
            height: parent.height - sideOrBottomPaneTopbar
            width: parent.width
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: sideOrBottomPaneTopbar.bottom
            visible: false
            color: "white"
            border.color: "darkblue"
            border.width: 1

            //blocking click events from beign captured by "below" elements...there is probably a better way to do that.
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    console.log('clicked featureDetailsPane')
                }
            }

            //this area holds buttons...essentially it is a "toolbar"
            Rectangle{
                id: featuredetailsPaneTopbar
                anchors.top: featureDetailsPane.top
                anchors.horizontalCenter: parent.horizontalCenter
                width:parent.width
                height: zoomButtons.width
                color: "darkblue"
                Button {
                    id:featuredetailsbackbutton
                    text: qsTr("Back / <br>Cancel ")
                    visible: if (sideOrBottomPaneContainerState == 'minimized' && isLandscape == true){false}else{featureDetailsPane.visible} //in this case hide becasue it looks silly then
                    enabled: true
                    anchors.top: parent.top
                    anchors.left:parent.left
                    anchors.bottom: parent.bottom
                    width: parent.width/6-1 -3
                    height: parent.height*0.5
                    anchors.margins: 2
                    style: ButtonStyle {
                        background: Rectangle {
                            border.color: if (enabled == false){'grey'}else{"white"}
                            border.width: 1
                            radius: 4
                            color: {
                                if (control.pressed == true){'#0000b3'}
                                else if (control.hovered == true){'#0000b3'}
                                else {'darkblue'}
                            }
                        }
                        label: Text {
                            text: control.text
                            color:if (enabled == false){'grey'}else{"white"}
                            clip:true
                            horizontalAlignment: Text.AlignHCenter
                            fontSizeMode: Text.Fit
                            minimumPointSize: 3
                            anchors.fill: parent                        }
                    }
                    onClicked: {
                        featureDetailsPane.visible = false;
                        editingMode = 'none'
                        relRecordEditingOperation = 'none'
                    }
                }
                Button {
                    id: featuredetailsattribeditbutton
                    text: if (editingMode == 'attr'){qsTr("  Save  <br> Attr.  ")} else{qsTr("  Edit  <br>  Attr. ")}
                    visible: if (sideOrBottomPaneContainerState == 'minimized' && isLandscape == true){false}else{true} //in this case hide becasue it looks silly then
                    width: parent.width/6 - 3
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    height: parent.height*0.5
                    anchors.left: featuredetailsbackbutton.right
                    enabled: if (editingMode == 'geom' | editingMode == 'ins' | editingMode == 'del' ){false}else{true}
                    anchors.margins: 2
                    style: ButtonStyle {
                        background: Rectangle {
                            border.color: if (enabled == false){'grey'}else{"white"}
                            border.width: 1
                            radius: 4
                            color: {
                                if (control.pressed == true){'#0000b3'}
                                else if (control.hovered == true){'#0000b3'}
                                else {'darkblue'}
                            }
                        }
                        label: Text {
                            text: control.text
                            color: if (enabled == false){'grey'}else{"white"}
                            clip:true
                            horizontalAlignment: Text.AlignHCenter
                            fontSizeMode: Text.Fit
                            minimumPointSize: 3
                            anchors.fill: parent
                        }
                    }
                    onClicked: {
                        if(editingMode == 'none'){
                            editingMode='attr'
                        }
                        //if we are in attribute editing mode then grab the attribute values currenly shown and push updates into the .geodatabase
                        else{
                            var featureToEdit = localPointsLayer.featureTable.feature(editedFeatureID);
                            for (var i = 0; i < column.children.length - 1; ++i){  //note add the -1 here becasue the last element is not a row but a repeater...not sure why, maybe that's how repeaters and colmns work.
                                var fieldName = column.children[i].children[0].text //this gets the nameLabel

                                var opentextfieldvalue = column.children[i].children[1].text //this gets the valueEdit from the open text field
                                var dropdownlistfieldvalue = column.children[i].children[2].currentText //this gets the selected choice from a drop down list

                                var fieldValue
                                if (column.children[i].children[1].visible == true){
                                    fieldValue = opentextfieldvalue
                                }
                                if (column.children[i].children[2].visible == true){
                                    fieldValue = dropdownlistfieldvalue
                                }
                                featureToEdit.setAttributeValue(fieldName , fieldValue);
                            }

                            featureToEdit.geometry = localPointsLayer.featureTable.feature(editedFeatureID).geometry;
                            console.log(JSON.stringify((featureToEdit.json)))
                            localPointsLayer.featureTable.updateFeature(editedFeatureID, featureToEdit)

                            editingMode='none'
                        };
                    }
                }

                Button {
                    id:featuredetailgeomeditbutton
                    visible: if (sideOrBottomPaneContainerState == 'minimized' && isLandscape == true){false}else{true} //in this case hide becasue it looks silly then
                    anchors.left: featuredetailsattribeditbutton.right
                    anchors.bottom: parent.bottom
                    height: parent.height*0.5 - 3
                    text: if (editingMode == 'geom'){qsTr("  Save  <br> Geom.  ")} else{qsTr("  Edit  <br> Geom.  ")}
                    width: parent.width/6
                    anchors.top: parent.top
                    enabled: if (editingMode == 'attr'|editingMode == 'ins' | editingMode == 'del' ){false}else{true}
                    anchors.margins: 2
                    style: ButtonStyle {
                        background: Rectangle {
                            border.color: if (enabled == false){'grey'}else{"white"}
                            border.width: 1
                            radius: 4
                            color: {
                                if (control.pressed == true){'#0000b3'}
                                else if (control.hovered == true){'#0000b3'}
                                else {'darkblue'}
                            }
                        }
                        label: Text {
                            text: control.text
                            color:if (enabled == false){'grey'}else{"white"}
                            clip:true
                            horizontalAlignment: Text.AlignHCenter
                            fontSizeMode: Text.Fit
                            minimumPointSize: 3
                            anchors.fill: parent
                        }
                    }
                    //the first time we click this button set the editing mode to geom. Second time Save the edit.
                    onClicked: {
                        if(editingMode == 'none'){
                            editingMode='geom' //can be 'none', 'geom', or 'attr'
                        }
                        else if (editingMode == 'geom'){
                            //push edit inot gdb
                            var featureToEdit = localPointsLayer.featureTable.feature(editedFeatureID);

                            //get the map center x,y coordinate
                            var xCoord = map.extent.center.x
                            var yCoord = map.extent.center.y

                            //set feature geometry
                            featureToEdit.geometry.setXY(xCoord, yCoord)

                            localPointsLayer.featureTable.updateFeature(editedFeatureID, featureToEdit)
                            console.log(JSON.stringify((featureToEdit.json)))
                            editingMode='none'
                        }
                    }
                }


                Button {
                    id:featuredetailsrelatebutton
                    visible: if (sideOrBottomPaneContainerState == 'minimized' && isLandscape == true){false}else{true} //in this case hide becasue it looks silly then
                    anchors.left: featuredetailgeomeditbutton.right
                    anchors.bottom: parent.bottom
                    height: parent.height*0.5
                    text: qsTr("Related <br>Records ")
                    width: parent.width/6 - 3
                    anchors.top: parent.top
                    enabled: if (editingMode == 'attr' | editingMode == 'geom'|editingMode == 'ins' | editingMode == 'del' ){false}else{true}
                    anchors.margins: 2
                    style: ButtonStyle {
                        background: Rectangle {
                            border.color: if (enabled == false){'grey'}else{"white"}
                            border.width: 1
                            radius: 4
                            color: {
                                if (control.pressed == true){'#0000b3'}
                                else if (control.hovered == true){'#0000b3'}
                                else {'darkblue'}
                            }
                        }
                        label: Text {
                            text: control.text
                            color:if (enabled == false){'grey'}else{"white"}
                            clip:true
                            horizontalAlignment: Text.AlignHCenter
                            fontSizeMode: Text.Fit
                            minimumPointSize: 3
                            anchors.fill: parent
                        }
                    }
                    //query the related records table for recrds with the point feature's editedFeatureRelateKeyValue
                    onClicked: {
                        relatedRecordsPane.visible = true;
                        featureDetailsPane.visible = false;
                        relQuery.where = relTable_fkField + " = '" + editedFeatureRelateKeyValue + "'"
                        localRelRecordsTable.queryFeatures(relQuery)
                    }
                }

                Button {
                    id:featuredetailsattachmentbutton
                    anchors.bottom: parent.bottom
                    visible: if (sideOrBottomPaneContainerState == 'minimized' && isLandscape == true){false}else{true} //in this case hide becasue it looks silly then
                    anchors.left:featuredetailsrelatebutton.right
                    text: qsTr("Attached<br> Files  ")
                    width: parent.width/6 - 3
                    height: parent.height*0.5
                    anchors.top: parent.top
                    enabled: if ((editingMode == 'attr') | editingMode == 'geom'|editingMode == 'ins' | editingMode == 'del' ){false}else{true}
                    anchors.margins: 2
                    style: ButtonStyle {
                        background: Rectangle {
                            border.color: if (enabled == false){'grey'}else{"white"}
                            border.width: 1
                            radius: 4
                            color: {
                                if (control.pressed == true){'#0000b3'}
                                else if (control.hovered == true){'#0000b3'}
                                else {'darkblue'}
                            }
                        }
                        label: Text {
                            text: control.text
                            color:if (enabled == false){'grey'}else{"white"}
                            clip:true
                            horizontalAlignment: Text.AlignHCenter
                            fontSizeMode: Text.Fit
                            minimumPointSize: 3
                            anchors.fill: parent
                        }
                    }
                    //query the points layer for attachments
                    onClicked: {
                        featureDetailsPane.visible = false;
                        attachmentsPane.visible = true;
                        localPointsLayer.featureTable.queryAttachmentInfos(editedFeatureID);
                    }
                }

                Button {
                    id:featuredetailsdeletebutton
                    visible: if (sideOrBottomPaneContainerState == 'minimized' && isLandscape == true){false}else{true} //in this case hide becasue it looks silly then
                    anchors.bottom: parent.bottom
                    text: if (editingMode == 'del'){qsTr("Confirm <br>Deletion")} else {qsTr(" Delete <br> Point  ")}
                    width: parent.width/6 - 3
                    height: parent.height*0.5
                    anchors.top: parent.top
                    anchors.left:featuredetailsattachmentbutton.right
                    enabled: if ((editingMode == 'attr') | (editingMode == 'geom'|editingMode == 'ins')){false}else{true}
                    anchors.margins: 2
                    style: ButtonStyle {
                        background: Rectangle {
                            border.color: if (enabled == false){'grey'}else{"white"}
                            border.width: 1
                            radius: 4
                            color: {
                                if (control.pressed == true){'#0000b3'}
                                else if (control.hovered == true){'#0000b3'}
                                else {'darkblue'}
                            }
                        }
                        label: Text {
                            text: control.text
                            color:if (enabled == false){'grey'}else{"white"}
                            clip:true
                            horizontalAlignment: Text.AlignHCenter
                            fontSizeMode: Text.Fit
                            minimumPointSize: 3
                            anchors.fill: parent
                        }
                    }

                    //only delete feature after clicked twice. after clicking once confirmation will be asked.
                    onClicked: {
                        if (editingMode == 'none'){
                            editingMode = 'del'
                        }
                        else if (editingMode == 'del'){
                            localPointsLayer.featureTable.deleteFeature(editedFeatureID);
                            clearSelectionsAndAssociatedModels();
                        }
                    }
                }
            }

            //this flickable lists the point feature attribute names and values
            Flickable {
                anchors.top:featuredetailsPaneTopbar.bottom
                anchors.bottom: featureDetailsPane.bottom
                anchors.left: featureDetailsPane.left
                anchors.right: featureDetailsPane.right
                contentHeight: column.height
                contentWidth: featureDetailsPane.width
                anchors.topMargin: 5
                clip:true

                ColumnLayout {
                    id: column
                    clip: true
                    width:parent.width

                    anchors {
                        left:parent.left
                        right:parent.right
                        margins: 5
                    }

                    Repeater {
                        model: fieldsModel
                        width: parent.width

                        Row {
                            id: row

                            Label {
                                id: nameLabel
                                text: name
                                color: "black"
                                width: if(isLandscape == true){((app.width * 0.33)*0.5)-5}else{app.width * 0.33 - 5}
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignLeft
                            }


                            TextField {
                                id: valueEdit
                                anchors.verticalCenter: parent.verticalCenter

                                width: if (isLandscape == true){(app.width * 0.66)*0.5 - 5}else{app.width * 0.66- 5}
                                visible: if (fieldtype == 'opentext'){true}else{false}
                                readOnly: if (name == 'created_user' | name == 'created_date' | name == 'last_edited_user' | name == 'last_edited_date'){true}else{if(editingMode =='attr'){false}else{true}}
                                text: if (fieldtype == 'opentext'){string}else{" "}
                                horizontalAlignment: Text.AlignHCenter
                                style: TextFieldStyle {
                                    textColor: "black"
                                    background: Rectangle {
                                        radius: 2
                                        color: if (name == 'created_user' | name == 'created_date' | name == 'last_edited_user' | name == 'last_edited_date'){'lightgrey'}else{'white'}
                                        width:parent.width
                                        border.color: "black"
                                        border.width: 1
                                    }
                                }
                            }
                            //this creates an attribute picklist
                            ComboBox {
                                //editable:  //this property could be used to set a hard constraint on this field
                                enabled:  if(editingMode =='attr'){true}else{false}
                                visible: if (fieldtype == 'dropdown'){true}else{false}
                                id:pointsdropdownlist
                                anchors.verticalCenter: parent.verticalCenter
                                model: if (fieldtype == 'dropdown'){choices.split(',')}else{['No predefined choices']}
                                width: if(isLandscape == true){(app.width * 0.66)*0.5 - 5}else{app.width * 0.66 - 5}
                                currentIndex: string //set inital value if value is found
                                style: EditComboBoxStyle{        }
                            }
                        }
                    }
                }
            }
        }

        //this is the container that is made visible when related tabe records are queried. it holds the associated toolbar, the relaed records, and thier attribute display
        Rectangle{
            id: relatedRecordsPane
            height: parent.height - sideOrBottomPaneTopbar
            width: parent.width
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: sideOrBottomPaneTopbar.bottom
            visible: false
            color: "white"
            border.color: "darkblue"
            border.width: 1
            MouseArea{
                anchors.fill: parent
                onClicked: {console.log('clicked relatedRecordsPane mousearea to block elements below')}
            }

            //the 'toolbar' for the related records container
            Rectangle {
                id: relrecordsbuttongrid
                anchors.top: parent.top
                height: zoomButtons.width
                width:parent.width
                color: "darkblue"
                Button {
                    id:relatedrecordspanebackbutton
                    visible: if (sideOrBottomPaneContainerState == 'minimized' && isLandscape == true){false}else{true} //in this case hide becasue it looks silly when minimized on teh side
                    text: qsTr(" Back/  <br> Cancel ")
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left:parent.left
                    anchors.margins: 2
                    width: parent.width/6 - 3
                    height: parent.height*0.5
                    style: ButtonStyle {
                        background: Rectangle {
                            border.color: if (enabled == false){'grey'}else{"white"}
                            border.width: 1
                            radius: 4
                            color: {
                                if (control.pressed == true){'#0000b3'}
                                else if (control.hovered == true){'#0000b3'}
                                else {'darkblue'}
                            }
                        }
                        label: Text {
                            text: control.text
                            color:if (enabled == false){'grey'}else{"white"}
                            clip:true
                            horizontalAlignment: Text.AlignHCenter
                            fontSizeMode: Text.Fit
                            minimumPointSize: 3
                            anchors.fill: parent
                        }
                    }
                    onClicked: {
                        relRecordEditingOperation = 'none'
                        relRecordsList.model.clear();
                        relatedRecordsPane.visible = false;
                        featureDetailsPane.visible = true;
                    }
                }


                Button {
                    id:relatedrecordspaneaddbutton
                    text: qsTr("  Add   <br>  New   ")
                    visible: if (sideOrBottomPaneContainerState == 'minimized' && isLandscape == true){false}else{true} //in this case hide becasue it looks silly when minimized on the side
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left:relatedrecordspanebackbutton.right
                    anchors.margins: 2
                    width: parent.width/6 - 3
                    height: parent.height*0.5
                    style: ButtonStyle {
                        background: Rectangle {
                            border.color: if (enabled == false){'grey'}else{"white"}
                            border.width: 1
                            radius: 4
                            color: {
                                if (control.pressed == true){'#0000b3'}
                                else if (control.hovered == true){'#0000b3'}
                                else {'darkblue'}
                            }
                        }
                        label: Text {
                            text: control.text
                            color:if (enabled == false){'grey'}else{"white"}
                            clip:true
                            horizontalAlignment: Text.AlignHCenter
                            fontSizeMode: Text.Fit
                            minimumPointSize: 3
                            anchors.fill: parent
                        }
                    }
                    onClicked: {
                        relRecordEditingOperation = 'Insert'
                        var featureJson = {
                            attributes:{}
                        }
                        featureJson.attributes[relTable_fkField] = editedFeatureRelateKeyValue
                        //here we could specify any defaut values for new related records.
                        console.log(JSON.stringify(featureJson))
                        localRelRecordsTable.addFeature(featureJson)
                        //refresh the list. the newly added record will appear and can thn be clicked to view/update attributes
                        relQuery.where = relTable_fkField + " = '" + editedFeatureRelateKeyValue + "'"
                        localRelRecordsTable.queryFeatures(relQuery)
                    }
                }

                Button {
                    id:relatedrecordspaneviewandupdatebutton
                    text: qsTr("View or <br> Update ")
                    anchors.top: parent.top
                    visible: if (sideOrBottomPaneContainerState == 'minimized' && isLandscape == true){false}else{true} //in this case hide becasue it looks silly when minimized on the side
                    enabled: if (relRecordsList.model.count > 0){true}else{false}
                    anchors.bottom: parent.bottom
                    anchors.left:relatedrecordspaneaddbutton.right
                    anchors.margins: 2
                    width: parent.width/6 - 3
                    height: parent.height*0.5
                    style: ButtonStyle {
                        background: Rectangle {
                            border.color: if (enabled == false){'grey'}else{"white"}
                            border.width: 1
                            radius: 4
                            color: {
                                if (control.pressed == true){'#0000b3'}
                                else if (control.hovered == true){'#0000b3'}
                                else {'darkblue'}
                            }
                        }
                        label: Text {
                            text: control.text
                            color:if (enabled == false){'grey'}else{"white"}
                            clip:true
                            horizontalAlignment: Text.AlignHCenter
                            fontSizeMode: Text.Fit
                            minimumPointSize: 3
                            anchors.fill: parent
                        }
                    }
                    onClicked: {
                        relRecordEditingOperation = 'Update'
                        var objectid = relRecordsList.model.get(relRecordsList.currentIndex).object_id
                        Helper.getRelTableFields(localRelRecordsTable, objectid)
                        editedRelatedFeatureID = objectid
                        relatedRecordFieldPane.visible = true
                        relRecordsList.visible = false
                    }
                }
                Button {
                    id:relatedrecordspanedeletebutton
                    text: if(relRecordEditingOperation == 'Delete'){qsTr("Confirm <br>Deletion")}else{qsTr(" Delete ")}
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    visible: if (sideOrBottomPaneContainerState == 'minimized' && isLandscape == true){false}else{true} //in this case hide becasue it looks silly then
                    enabled: if (relRecordsList.model.count > 0){true}else{false}
                    anchors.left:relatedrecordspaneviewandupdatebutton.right
                    anchors.margins: 2
                    width: parent.width/6 - 3
                    height: parent.height*0.5
                    style: ButtonStyle {
                        background: Rectangle {
                            border.color: if (enabled == false){'grey'}else{"white"}
                            border.width: 1
                            radius: 4
                            color: {
                                if (control.pressed == true){'#0000b3'}
                                else if (control.hovered == true){'#0000b3'}
                                else {'darkblue'}
                            }
                        }
                        label: Text {
                            text: control.text
                            color:if (enabled == false){'grey'}else{"white"}
                            clip:true
                            horizontalAlignment: Text.AlignHCenter
                            fontSizeMode: Text.Fit
                            minimumPointSize: 3
                            anchors.fill: parent
                        }
                    }
                    onClicked: {
                        if (relRecordEditingOperation != 'Delete'){
                            relRecordEditingOperation = 'Delete'
                        }
                        else if(relRecordEditingOperation = 'Delete'){
                            var objectid = relRecordsList.model.get(relRecordsList.currentIndex).object_id
                            localRelRecordsTable.deleteFeature(objectid)
                            console.log('deleted the selected related record')
                            //refresh the list view by querying the table
                            relQuery.where = relTable_fkField + " = '" + editedFeatureRelateKeyValue + "'"
                            localRelRecordsTable.queryFeatures(relQuery)
                        }
                    }
                }
            }

            //the listview of related records. referenced from other qml file.
            RelRecordsList{
                id: relRecordsList
            }
        }

        Rectangle{
            id: relatedRecordFieldPane
            height: parent.height - sideOrBottomPaneTopbar
            width: parent.width
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: sideOrBottomPaneTopbar.bottom
            visible: false
            color:"white"
            border.color: "darkblue"
            border.width: 1
            Rectangle {
                id: relrecordsfieldpanebuttongrid
                anchors.top: parent.top
                height: zoomButtons.width
                width:parent.width
                color: "darkblue"

                Button {
                    id:relrecordsfieldpanebackbutton
                    text: qsTr(" Back / <br> Cancel ")
                    visible: if (sideOrBottomPaneContainerState == 'minimized' && isLandscape == true){false}else{true} //in this case hide becasue it looks silly then
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left:parent.left
                    anchors.margins: 2
                    width: parent.width/6 - 3
                    height: parent.height*0.5
                    style: ButtonStyle {
                        background: Rectangle {
                            border.color: 'white'
                            border.width: 1
                            radius: 4
                            color: {
                                if (control.pressed == true){'#0000b3'}
                                else if (control.hovered == true){'#0000b3'}
                                else {'darkblue'}
                            }
                        }
                        label: Text {
                            text: control.text
                            color:"white"
                            clip:true
                            horizontalAlignment: Text.AlignHCenter
                            fontSizeMode: Text.Fit
                            minimumPointSize: 3
                            anchors.fill: parent
                        }
                    }
                    onClicked: {
                        relTableFieldsModel.clear();
                        relatedRecordFieldPane.visible = false;
                        relatedRecordsPane.visible  = true;
                        relRecordsList.visible = true
                        relRecordEditingOperation = ''
                    }
                }

                Button {
                    id:relatedrecordspanesavebutton
                    text: qsTr("  Save  ")
                    visible: if (sideOrBottomPaneContainerState == 'minimized' && isLandscape == true){false}else{true} //in this case hide becasue it looks silly then
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left:relrecordsfieldpanebackbutton.right
                    anchors.margins: 2
                    width: parent.width/6 - 3
                    height: parent.height*0.5
                    style: ButtonStyle {
                        background: Rectangle {
                            border.color: if (enabled == false){'grey'}else{"white"}
                            border.width: 1
                            radius: 4
                            color: {
                                if (control.pressed == true){'#0000b3'}
                                else if (control.hovered == true){'#0000b3'}
                                else {'darkblue'}
                            }
                        }
                        label: Text {
                            text: control.text
                            color:if (enabled == false){'grey'}else{"white"}
                            clip:true
                            horizontalAlignment: Text.AlignHCenter
                            fontSizeMode: Text.Fit
                            minimumPointSize: 3
                            anchors.fill: parent
                        }
                    }
                    onClicked: {
                        Helper.updateRelatedRecord(editedRelatedFeatureID)
                        relTableFieldsModel.clear();
                        relatedRecordFieldPane.visible = false;
                        relatedRecordsPane.visible  = true;
                        relRecordsList.visible = true
                        relRecordEditingOperation = ''
                        //refresh the list view by querying the table
                        relQuery.where = relTable_fkField + " = '" + editedFeatureRelateKeyValue + "'"
                        localRelRecordsTable.queryFeatures(relQuery)
                    }
                }
            }

            Flickable {
                id:relRecordFieldsList
                anchors.top:relrecordsfieldpanebuttongrid.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                contentHeight: relTableFieldsColumn.height
                contentWidth: parent.width
                clip: true
                anchors.topMargin: 5

                ColumnLayout {
                    id: relTableFieldsColumn
                    clip: true
                    width: parent.width

                    anchors {
                        left:parent.left
                        right:parent.right
                        margins: 5
                    }

                    Repeater {
                        model: relTableFieldsModel
                        width: parent.width

                        Row {
                            id: relRow
                            Label {
                                id: relNameLabel
                                text: name
                                color: "black"
                                horizontalAlignment: Text.AlignLeft
                                anchors.verticalCenter: parent.verticalCenter
                                width: if(isLandscape == true){((app.width * 0.33)*0.5)-5}else{app.width * 0.33 - 5}
                            }

                            TextField {
                                id: relValueEdit
                                //make editor tracking fields read-only.
                                readOnly: if (name == 'created_user' | name == 'created_date' | name == 'last_edited_user' | name == 'last_edited_date'){true}else{false}
                                anchors.verticalCenter: parent.verticalCenter
                                text: if (fieldtype == 'opentext'){string}else{" "}
                                horizontalAlignment: Text.AlignHCenter
                                width: if (isLandscape == true){(app.width * 0.66)*0.5 - 5}else{app.width * 0.66- 5}
                                visible: if (fieldtype == 'opentext'){true}else{false}
                                style: TextFieldStyle {
                                    textColor: "black"
                                    background: Rectangle {
                                        radius: 2
                                        color: if (name == 'created_user' | name == 'created_date' | name == 'last_edited_user' | name == 'last_edited_date'){'lightgrey'}else{'white'}
                                        width:parent.width
                                        border.color: "black"
                                        border.width: 1
                                    }
                                }
                            }

                            //attribute domains
                            ComboBox {
                                visible: if (fieldtype == 'dropdown'){true}else{false}
                                id:reldropdownlist
                                model: if (fieldtype == 'dropdown'){choices.split(',')}else{['No predefined choices']}
                                width: if(isLandscape == true){(app.width * 0.66)*0.5 - 5}else{app.width * 0.66 - 5}
                                anchors.verticalCenter: parent.verticalCenter
                                currentIndex: string //set inital value if value is found
                                style: EditComboBoxStyle{        }
                            }
                        }
                    }
                }
            }

            ListModel {
                id: relTableFieldsModel
            }
        }

        Rectangle{
            id: attachmentsPane
            height: parent.height - sideOrBottomPaneTopbar
            width: parent.width
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: sideOrBottomPaneTopbar.bottom
            visible: false
            color: "white"
            border.color: "darkblue"
            border.width: 1
            MouseArea{
                anchors.fill: parent
                onClicked: {console.log('clicked attachmentsPane mousearea to block elements below')}
            }
            Rectangle {
                id: attachmentsbuttongrid
                anchors.top: parent.top
                height: zoomButtons.width
                width:parent.width
                color: "darkblue"
                Button {
                    id:attachmentspanebackbutton
                    text: qsTr(" Back / <br> Cancel ")
                    anchors.top: parent.top
                    visible: if (sideOrBottomPaneContainerState == 'minimized' && isLandscape == true){false}else{true} //in this case hide becasue it looks silly when minimized on side
                    anchors.bottom: parent.bottom
                    anchors.left:parent.left
                    anchors.margins: 2
                    width: parent.width/6 - 3
                    height: parent.height*0.5
                    style: ButtonStyle {
                        background: Rectangle {
                            border.color: if (enabled == false){'grey'}else{"white"}
                            border.width: 1
                            radius: 4
                            color: {
                                if (control.pressed == true){'#0000b3'}
                                else if (control.hovered == true){'#0000b3'}
                                else {'darkblue'}
                            }
                        }
                        label: Text {
                            text: control.text
                            color:if (enabled == false){'grey'}else{"white"}
                            clip:true
                            horizontalAlignment: Text.AlignHCenter
                            fontSizeMode: Text.Fit
                            minimumPointSize: 3
                            anchors.fill: parent
                        }
                    }
                    onClicked: {
                        featureDetailsPane.visible = true;
                        attachmentsPane.visible = false;
                        attachmentsList.model.clear();
                        attachmenteditingMode = 'none'
                    }
                }
                Button {
                    id:attachmentspaneviewbutton
                    text: qsTr("  View  <br>Selected")
                    visible: if (sideOrBottomPaneContainerState == 'minimized' && isLandscape == true){false}else{true} //in this case hide becasue it looks silly when minimized on side
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left:attachmentspanebackbutton.right
                    anchors.margins: 2
                    width: parent.width/6 - 3
                    height: parent.height*0.5
                    enabled: attachmentsList.currentIndex != -1 ? true : false
                    style: ButtonStyle {
                        background: Rectangle {
                            border.color: if (enabled == false){'grey'}else{"white"}
                            border.width: 1
                            radius: 4
                            color: {
                                if (control.pressed == true){'#0000b3'}
                                else if (control.hovered == true){'#0000b3'}
                                else {'darkblue'}
                            }
                        }
                        label: Text {
                            text: control.text
                            color:if (enabled == false){'grey'}else{"white"}
                            clip:true
                            horizontalAlignment: Text.AlignHCenter
                            fontSizeMode: Text.Fit
                            minimumPointSize: 3
                            anchors.fill: parent
                        }
                    }
                    onClicked: {
                        attachmenteditingMode = 'none'
                        var item = attachmentsList.model.get(attachmentsList.currentIndex);
                        localPointsLayer.featureTable.retrieveAttachment(editedFeatureID, item["attachmentId"]);
                    }
                }
                Button {
                    id:attachmentspaneaddbutton
                    text: qsTr("  Add   <br>  New   ")
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    visible: if (sideOrBottomPaneContainerState == 'minimized' && isLandscape == true){false}else{true} //in this case hide becasue it looks silly when minimized on side
                    anchors.left:attachmentspaneviewbutton.right
                    anchors.margins: 2
                    width: parent.width/6 - 3
                    height: parent.height*0.5
                    enabled: editedFeatureID !== '' ? true : false
                    style: ButtonStyle {
                        background: Rectangle {
                            border.color: if (enabled == false){'grey'}else{"white"}
                            border.width: 1
                            radius: 4
                            color: {
                                if (control.pressed == true){'#0000b3'}
                                else if (control.hovered == true){'#0000b3'}
                                else {'darkblue'}
                            }
                        }
                        label: Text {
                            text: control.text
                            color:if (enabled == false){'grey'}else{"white"}
                            clip:true
                            horizontalAlignment: Text.AlignHCenter
                            fontSizeMode: Text.Fit
                            minimumPointSize: 3
                            anchors.fill: parent
                        }
                    }
                    onClicked: {
                        attachmenteditingMode = 'none'
                        //this could be used for possible enhancement of alowing file uploads, for example only when not on Androi or iOS. future enhancement.
                        //if (Qt.platform.os === "ios" || Qt.platform.os === "android") {
                        if (1 ==1 ){
                            visiblePane = 'cameracontainer'
                            sideOrBottomPaneContainerState = 'minimized'
                        }
                    }
                }
                Button {
                    id:attachmentspanedeletebutton
                    text: if (attachmenteditingMode == 'del'){qsTr("Confirm <br>Deletion")} else {qsTr(" Delete <br>Selected")}
                    anchors.top: parent.top
                    visible: if (sideOrBottomPaneContainerState == 'minimized' && isLandscape == true){false}else{true} //in this case hide becasue it looks silly when miminized on side
                    anchors.bottom: parent.bottom
                    anchors.left:attachmentspaneaddbutton.right
                    anchors.margins: 2
                    width: parent.width/6 - 3
                    height: parent.height*0.5
                    enabled: attachmentsList.currentIndex != -1 ? true : false
                    style: ButtonStyle {
                        background: Rectangle {
                            border.color: if (enabled == false){'grey'}else{"white"}
                            border.width: 1
                            radius: 4
                            color: {
                                if (control.pressed == true){'#0000b3'}
                                else if (control.hovered == true){'#0000b3'}
                                else {'darkblue'}
                            }
                        }
                        label: Text {
                            text: control.text
                            color:if (enabled == false){'grey'}else{"white"}
                            clip:true
                            horizontalAlignment: Text.AlignHCenter
                            fontSizeMode: Text.Fit
                            minimumPointSize: 3
                            anchors.fill: parent
                        }
                    }
                    onClicked: {
                        if (attachmenteditingMode == 'none'){
                            attachmenteditingMode = 'del'
                        }
                        else if (attachmenteditingMode == 'del'){
                            var item = attachmentsList.model.get(attachmentsList.currentIndex);
                            localPointsTable.deleteAttachment(editedFeatureID, item["attachmentId"]);
                            attachmenteditingMode = 'none'
                        }
                    }
                }
            }
            //the list of exisitng attachments. referenced from other qml file
            AttachmentsList{
                id: attachmentsList
            }
        }
    }

    Rectangle{
        anchors.fill: parent
        color:'white'
        opacity: 0.75
        visible: attachmentImage.source != "" ? true : false
    }
    Image {
        id: attachmentImage
        width: parent.width
        height: parent.height
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        visible: attachmentImage.source != "" ? true : false
        fillMode: Image.PreserveAspectFit

        MouseArea {
            anchors.fill: parent
            onClicked: {
                attachmentImage.source = ""
            }
        }
    }

    //--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    //BEGIN WELCOMEMENU
    Rectangle{
        id: welcomemenucontainer
        anchors.top: mapcontainer.top
        anchors.bottom: app.bottom
        anchors.right: app.right
        anchors.left: app.left
        color:"lightgrey"
        visible: if (visiblePane === 'welcomemenucontainer'){true}else{false}

        //MoueArea to prevent interaction with the map when it is "behind" the welcomemenu.
        //There's probably a more elegant way to doing this.
        MouseArea{
            anchors.fill: parent
        }

        Rectangle{
            id:titlecontainer
            height: welcomemenucontainer.height / 6
            width: welcomemenucontainer.width
            anchors.left:parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            color:"white"
            anchors.margins: 6
            border.width: 1
            border.color: "grey"
            Text{
                id:appdescription
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.left: parent.left
                anchors.margins: 5
                height: parent.height
                width:parent.width
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                clip:true
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment:Text.AlignHCenter
                color: "black"
                fontSizeMode: Text.Fit
                minimumPointSize: 4
                font.pointSize: 10
                text: app.info.propertyValue("App Description","Sign in, download the basemap tile package, then download the secured floor plan feature layers and off you go. On the map you can view interior building layouts. Sync it now and again to get the latest updates downloaded to your device.");
            }
        }
        Rectangle{
            id: signInDialogContainer
            height: welcomemenucontainer.height / 8
            width: welcomemenucontainer.width
            anchors.left:parent.left
            anchors.right: parent.right
            anchors.top: titlecontainer.bottom
            color:"white"
            anchors.margins: 6
            visible:true
            border.width: 1
            border.color: "grey"

            StyleButtonNoFader{
                id: signInButton
                visible: true
                height: parent.height
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.bottom: signInDialogContainer.bottom
                anchors.margins: 2
                anchors.rightMargin: 20
                anchors.leftMargin: 20
                width: parent.width * 0.9
                pressedColor: "white"
                backgroundColor: "white"
                focusBorderColor: "blue"
                borderColor: "black"

                Image {
                    id: signInButtonIcon
                    anchors.left: parent.left
                    anchors.top:parent.top
                    anchors.bottom: parent.bottom
                    width: height
                    source: "images/user.png"
                    fillMode: Image.PreserveAspectFit
                    anchors.margins: 2
                    opacity: 1
                }
                Text{
                    id: singInButtonText
                    text:"<b>Sign in</b><br>Required to edit and sync map layers. This requires starting the app while connected to internet."
                    anchors.left: signInButtonIcon.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: signInButton.right
                    anchors.margins: 2
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    clip:true
                    horizontalAlignment:Text.AlignHCenter
                    fontSizeMode: Text.Fit
                    minimumPointSize: 4
                    font.pointSize: 16
                    verticalAlignment: Text.AlignVCenter
                    color: "black"
                }
                onClicked: {
                    console.log('clicked signInButton')
                    if (AppFramework.network.isOnline == true){
                        if (signedInToPortal){
                            console.log('you are already signed in.')
                        }
                        else{
                            visiblePane = 'webviewcontainer'
                        }
                    }
                    else{
                        singInButtonText.text = "No network connection. To sign in you need to start the app while connected to the internet."
                        console.log("No network connection. To sign in you need to start the app while connected to the internet.")
                    }
                }
            }
        }

        Rectangle{
            id:tpkinfocontainer
            height: welcomemenucontainer.height / 6
            width: welcomemenucontainer.width
            anchors.right:parent.right
            anchors.left: parent.left
            anchors.top: signInDialogContainer.bottom
            color:"white"
            anchors.margins: 6
            border.width: 1
            border.color: "grey"

            Text{
                id: tpkinfobuttonheader
                anchors.bottom:tpkinfoimagebutton.top
                anchors.top: tpkinfocontainer.top
                anchors.right:parent.right
                anchors.left: parent.left
                color:"black"
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                clip:true
                horizontalAlignment:Text.AlignHCenter
                fontSizeMode: Text.Fit
                minimumPointSize: 4
                font.pointSize: 16
                anchors.margins: 2
                verticalAlignment: Text.AlignVCenter
                font.weight: Font.DemiBold
                text:" Basemap Layer "
            }
            StyleButtonNoFader{
                id:tpkinfoimagebutton
                height: parent.height / 3
                anchors.left: parent.left
                anchors.right: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width / 2
                anchors.rightMargin: 20
                anchors.leftMargin: 20
                pressedColor: "white"
                backgroundColor: "white"
                focusBorderColor: "black"
                borderColor: "black"

                Image {
                    id: tpkinfoimagebuttonIcon
                    anchors.left: parent.left
                    anchors.top:parent.top
                    anchors.bottom: parent.bottom
                    width: height
                    source: "images/download.png"
                    fillMode: Image.Stretch
                    anchors.margins: 3
                }
                Text{
                    id: tpkinfoimagebuttonText
                    text: "Download copy to device"
                    anchors.left: tpkinfoimagebuttonIcon.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: tpkinfoimagebutton.right
                    anchors.margins: 2
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    clip:true
                    horizontalAlignment:Text.AlignHCenter
                    fontSizeMode: Text.Fit
                    minimumPointSize: 4
                    font.pointSize: 16
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked:{
                    groupLayer.removeAllLayers();
                    tpkFolder.removeFolder() //delete the tpk from local storage
                    tpkFolder.downloadThenAddLayer() //download and add the tpk layer
                }
            }
            StyleButtonNoFader{
                id:tpkDeleteButton
                anchors.top: tpkinfoimagebutton.top
                anchors.bottom: tpkinfoimagebutton.bottom
                anchors.left: parent.horizontalCenter
                anchors.right: parent.right
                width: parent.width / 2
                anchors.rightMargin: 20
                anchors.leftMargin: 20
                pressedColor: "white"
                backgroundColor: "white"
                focusBorderColor: "blue"
                borderColor: if (tpkfile.exists == true){"black"} else {"lightgrey"}
                enabled: if (tpkfile.exists == true){true} else {false}

                Image {
                    id: tpkDeleteButtonIcon
                    anchors.left: parent.left
                    anchors.top:parent.top
                    anchors.bottom: parent.bottom
                    width: height
                    source: "images/DeleteWinIcon.png"
                    fillMode: Image.Stretch
                    anchors.margins: 2
                    opacity: if (tpkfile.exists == true){1} else {0.40}
                }

                Text{
                    id: tpkDeleteButtonText
                    text: "Remove copy from device"
                    anchors.left: tpkDeleteButtonIcon.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: tpkDeleteButton.right
                    anchors.margins: 2
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    clip:true
                    horizontalAlignment:Text.AlignHCenter
                    fontSizeMode: Text.Fit
                    minimumPointSize: 4
                    font.pointSize: 16
                    verticalAlignment: Text.AlignVCenter
                    color: if (tpkfile.exists == true){"black"} else {"lightgrey"}
                }

                //don't immediately remove the .tpk because of file locking issues
                onClicked:{
                    if (tpkDeleteButtonText.text === "Undo"){
                        tpkFolder.removeFile("nextTimeDeleteTPKfile.txt")
                        tpkDeleteButtonText.text = "Remove copy from device"
                        Helper.doorkeeper()
                    }
                    else{
                        tpkFolder.writeFile("nextTimeDeleteTPKfile.txt","Tile package will be deleted the next time the app is being started.")
                        tpkDeleteButtonText.text = "Undo"
                        tpkinfobuttontext.text = '<b><font color="red"> Device copy of basemap layer set to be removed next time app is opened. </font><\b>'
                    }
                }
            }
            Text{
                id: tpkinfobuttontext
                anchors.top:tpkinfoimagebutton.bottom
                anchors.bottom: tpkinfocontainer.bottom
                anchors.right:parent.right
                anchors.left: parent.left
                anchors.topMargin:6
                anchors.bottomMargin: 2
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                color:"black"
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                clip:true
                horizontalAlignment:Text.AlignHCenter
                fontSizeMode: Text.Fit
                minimumPointSize: 4
                font.pointSize: 10
                verticalAlignment: Text.AlignVCenter
            }
        }

        Rectangle{
            id:gdbinfocontainer
            height: welcomemenucontainer.height / 6
            width: welcomemenucontainer.width
            anchors.right:parent.right
            anchors.left: parent.left
            anchors.top: tpkinfocontainer.bottom
            color:"white"
            anchors.margins: 6
            border.width: 1
            border.color: "grey"

            Text{
                id: gdbinfobuttonheader
                anchors.bottom:gdbinfoimagebutton.top
                anchors.top: gdbinfocontainer.top
                anchors.right:parent.right
                anchors.left: parent.left
                color:"black"
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                clip:true
                horizontalAlignment:Text.AlignHCenter
                fontSizeMode: Text.Fit
                minimumPointSize: 4
                font.pointSize: 16
                anchors.margins: 2
                verticalAlignment: Text.AlignVCenter
                font.weight: Font.DemiBold
                text:" Floorplans Layer "
            }

            StyleButtonNoFader{
                id:gdbinfoimagebutton
                height: parent.height / 3
                anchors.left: parent.left
                anchors.right: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width / 2
                anchors.rightMargin: 20
                anchors.leftMargin: 20
                pressedColor: "white"
                backgroundColor: "white"
                focusBorderColor: if (gdbinfoimagebutton.enabled == false){"lightgrey"}else{"black"}
                borderColor: if (gdbinfoimagebutton.enabled == false){"lightgrey"}else{"black"}
                enabled: false

                Image {
                    id: gdbinfoimagebuttonIcon
                    anchors.left: parent.left
                    anchors.top:parent.top
                    anchors.bottom: parent.bottom
                    width: height
                    source: "images/download.png"
                    fillMode: Image.Stretch
                    anchors.margins: 3
                    opacity: if (gdbinfoimagebutton.enabled == false){0.4}else{1}
                }
                Text{
                    id: gdbinfoimagebuttonText
                    text: "Download/Sync device copy"
                    anchors.left: gdbinfoimagebuttonIcon.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: gdbinfoimagebutton.right
                    anchors.margins: 2
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    clip:true
                    horizontalAlignment:Text.AlignHCenter
                    fontSizeMode: Text.Fit
                    minimumPointSize: 4
                    font.pointSize: 16
                    verticalAlignment: Text.AlignVCenter
                    color: if (gdbinfoimagebutton.enabled == false){"lightgrey"}else{"black"}
                }

                onClicked:{
                    if (gdbfile.exists){
                        gdbfile.syncgdb();
                    }
                    else {
                        gdbfile.generategdb();
                    }
                }
                Rectangle{
                    id:rectangleBlockGDBDownloadUntilTPKisPresent
                    anchors.fill: parent
                    color: "white"
                    opacity: if(tpkfile.exists == false){0.5}else{0}
                }

                //blocking the clicking of button...
                MouseArea{
                    id: mouseAreaBlockGDBDownloadUntilTPKisPresent
                    anchors.fill: parent
                    enabled: if(tpkfile.exists == false){true}else{false}
                    onClicked: console.log("clicked mouseAreaBlockGDBDownloadUntilTPKisPresent")
                }
            }

            StyleButtonNoFader{
                id:gdbDeleteButton
                anchors.top: gdbinfoimagebutton.top
                anchors.bottom: gdbinfoimagebutton.bottom
                anchors.left: parent.horizontalCenter
                anchors.right: parent.right
                width: parent.width / 2
                anchors.rightMargin: 20
                anchors.leftMargin: 20
                pressedColor: "white"
                backgroundColor: "white"
                focusBorderColor: "blue"
                borderColor: if (gdbfile.exists == true){"black"} else {"lightgrey"}
                enabled: if (gdbfile.exists == true){true} else {false}

                Image {
                    id: gdbDeleteButtonIcon
                    anchors.left: parent.left
                    anchors.top:parent.top
                    anchors.bottom: parent.bottom
                    width: height
                    source: "images/DeleteWinIcon.png"
                    fillMode: Image.Stretch
                    anchors.margins: 2
                    opacity: if (gdbfile.exists == true){1} else {0.40}
                }
                Text{
                    id: gdbDeleteButtonText
                    text: "Remove copy from device"
                    anchors.left: gdbDeleteButtonIcon.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: gdbDeleteButton.right
                    anchors.margins: 2
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    clip:true
                    horizontalAlignment:Text.AlignHCenter
                    fontSizeMode: Text.Fit
                    minimumPointSize: 4
                    font.pointSize: 16
                    verticalAlignment: Text.AlignVCenter
                    color: if (gdbfile.exists == true){"black"} else {"lightgrey"}
                    enabled: if (gdbfile.exists == true){true}else{false}
                }
                onClicked:{
                    //this if else statment is a workaround to the fact that nextTimeDeleteGDBfile.exists always evaluates to false for some reason.
                    if (gdbDeleteButtonText.text === "Undo"){
                        syncLogFolder.removeFile("nextTimeDeleteGDB.txt")
                        gdbDeleteButtonText.text = "Remove copy from device"
                        Helper.doorkeeper()
                    }
                    else if (nextTimeDeleteGDBfile.exists == false){
                        syncLogFolder.writeFile("nextTimeDeleteGDB.txt","Offline Geodatabase will be deleted the next time the app is being started.")
                        gdbDeleteButtonText.text = "Undo"
                        gdbinfobuttontext.text = '<b><font color="red"> Device copy of operational layers set to be removed next time app is opened. </font><\b>'
                    }
                }
            }

            Text{
                id: gdbinfobuttontext
                anchors.top:gdbinfoimagebutton.bottom
                anchors.bottom: gdbinfocontainer.bottom
                anchors.right:parent.right
                anchors.left: parent.left
                anchors.topMargin:6
                anchors.bottomMargin: 2
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                color:"black"
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                clip:true
                horizontalAlignment:Text.AlignHCenter
                fontSizeMode: Text.Fit
                minimumPointSize: 4
                font.pointSize: 10
                verticalAlignment: Text.AlignVCenter
                text: " Download floor plan operational layers to be able to proceed. (Requires Sign in and downloaded basemap tile package.)"
            }
        }

        Rectangle{
            id:gdbinfocontainer2
            height: welcomemenucontainer.height / 6
            width: welcomemenucontainer.width
            anchors.right:parent.right
            anchors.left: parent.left
            anchors.top: gdbinfocontainer.bottom
            color:"white"
            anchors.margins: 6
            border.width: 1
            border.color: "grey"

            Text{
                id: gdbinfobuttonheader2
                anchors.bottom:gdbinfoimagebutton2.top
                anchors.top: gdbinfocontainer2.top
                anchors.right:parent.right
                anchors.left: parent.left
                color:"black"
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                clip:true
                horizontalAlignment:Text.AlignHCenter
                fontSizeMode: Text.Fit
                minimumPointSize: 4
                font.pointSize: 16
                anchors.margins: 2
                verticalAlignment: Text.AlignVCenter
                font.weight: Font.DemiBold
                text: " Editable Points Layer "
            }

            StyleButtonNoFader{
                id:gdbinfoimagebutton2
                height: parent.height / 3
                anchors.left: parent.left
                anchors.right: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width / 2
                anchors.rightMargin: 20
                anchors.leftMargin: 20
                pressedColor: "white"
                backgroundColor: "white"
                focusBorderColor: if (gdbinfoimagebutton2.enabled == false){"lightgrey"}else{"black"}
                borderColor: if (gdbinfoimagebutton2.enabled == false){"lightgrey"}else{"black"}
                enabled: false

                Image {
                    id: gdbinfoimagebuttonIcon2
                    anchors.left: parent.left
                    anchors.top:parent.top
                    anchors.bottom: parent.bottom
                    width: height
                    source: "images/download.png"
                    fillMode: Image.Stretch
                    anchors.margins: 3
                    opacity: if (gdbinfoimagebutton2.enabled == false){0.4}else{1}
                }
                Text{
                    id: gdbinfoimagebuttonText2
                    text: "Download/Sync device copy"
                    anchors.left: gdbinfoimagebuttonIcon2.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: gdbinfoimagebutton2.right
                    anchors.margins: 2
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    clip:true
                    horizontalAlignment:Text.AlignHCenter
                    fontSizeMode: Text.Fit
                    minimumPointSize: 4
                    font.pointSize: 16
                    verticalAlignment: Text.AlignVCenter
                    color: if (gdbinfoimagebutton2.enabled == false){"lightgrey"}else{"black"}
                }

                onClicked:{
                    if (gdbfile2.exists){
                        gdbfile2.syncgdb();
                    }
                    else {
                        gdbfile2.generategdb();
                    }
                }
                Rectangle{
                    id:rectangleBlockGDBDownloadUntilTPKisPresent2
                    anchors.fill: parent
                    color: "white"
                    opacity: if(tpkfile.exists == false){0.5}else{0}
                }

                //blocking the clicking of button...
                MouseArea{
                    id: mouseAreaBlockGDBDownloadUntilTPKisPresent2
                    anchors.fill: parent
                    enabled: if(tpkfile){false}else{true}
                    onClicked: console.log("clicked mouseAreaBlockGDBDownloadUntilTPKisPresent")
                }
            }

            StyleButtonNoFader{
                id:gdbDeleteButton2
                anchors.top: gdbinfoimagebutton2.top
                anchors.bottom: gdbinfoimagebutton2.bottom
                anchors.left: parent.horizontalCenter
                anchors.right: parent.right
                width: parent.width / 2
                anchors.rightMargin: 20
                anchors.leftMargin: 20
                pressedColor: "white"
                backgroundColor: "white"
                focusBorderColor: "blue"
                borderColor: if (gdbfile2.exists == true){"black"} else {"lightgrey"}
                enabled: if (gdbfile2.exists == true){true} else {false}

                Image {
                    id: gdbDeleteButtonIcon2
                    anchors.left: parent.left
                    anchors.top:parent.top
                    anchors.bottom: parent.bottom
                    width: height
                    source: "images/DeleteWinIcon.png"
                    fillMode: Image.Stretch
                    anchors.margins: 2
                    opacity: if (gdbfile2.exists == true){1} else {0.40}
                }
                Text{
                    id: gdbDeleteButtonText2
                    text: "Remove copy from device"
                    anchors.left: gdbDeleteButtonIcon2.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: gdbDeleteButton2.right
                    anchors.margins: 2
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    clip:true
                    horizontalAlignment:Text.AlignHCenter
                    fontSizeMode: Text.Fit
                    minimumPointSize: 4
                    font.pointSize: 16
                    verticalAlignment: Text.AlignVCenter
                    color: if (gdbfile2.exists == true){"black"} else {"lightgrey"}
                    enabled: if (gdbfile2.exists == true){true}else{false}
                }
                onClicked:{
                    //this if else statment is a workaround to the fact that nextTimeDeleteGDB2file.exists always evaluates to false for some reason.
                    if (gdbDeleteButtonText2.text === "Undo"){
                        syncLogFolder2.removeFile("nextTimeDeleteGDB2.txt")
                        gdbDeleteButtonText2.text = "Remove copy from device"
                        Helper.doorkeeper()
                    }
                    else if (nextTimeDeleteGDBfile2.exists == false){
                        syncLogFolder2.writeFile("nextTimeDeleteGDB2.txt","Offline Geodatabase will be deleted the next time the app is being started.")
                        gdbDeleteButtonText2.text = "Undo"
                        gdbinfobuttontext2.text = '<b><font color="red"> Device copy of operational layers set to be removed next time app is opened. </font><\b>'
                    }
                }
            }

            Text{
                id: gdbinfobuttontext2
                anchors.top:gdbinfoimagebutton2.bottom
                anchors.bottom: gdbinfocontainer2.bottom
                anchors.right:parent.right
                anchors.left: parent.left
                anchors.topMargin:6
                anchors.bottomMargin: 2
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                color:"black"
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                clip:true
                horizontalAlignment:Text.AlignHCenter
                fontSizeMode: Text.Fit
                minimumPointSize: 4
                font.pointSize: 10
                verticalAlignment: Text.AlignVCenter
                text: " Download asset points layer to be able to proceed. (Requires Sign in and downloaded basemap tile package.)"
            }
        }

        Rectangle{
            id: proceedbuttoncontainer
            width: welcomemenucontainer.width
            anchors.right:parent.right
            anchors.left: parent.left
            anchors.bottom: welcomemenucontainer.bottom
            anchors.top: gdbinfocontainer2.bottom
            color: (proceedbuttoncontainermousearea.enabled) ? "green" : "red"
            anchors.margins: 6
            border.color: "grey"
            border.width: 1
            clip: true

            function proceedToMap(){
                visiblePane = 'mapcontainer'
                Helper.getAllBldgs()//builds the list used for building search
                clearSelectionsAndAssociatedModels();
            }

            ImageButton{
                id: proceedtomapimagebutton
                source:"images/gallery-white.png"
                height: proceedbuttoncontainer.height / 1.5
                width: height
                anchors.top:proceedbuttoncontainer.top
                anchors.horizontalCenter: proceedbuttoncontainer.horizontalCenter
                enabled: proceedbuttoncontainermousearea.enabled
                onClicked: {
                    visiblePane = 'mapcontainer'
                    Helper.getAllBldgs()//builds the list used for building search
                }
            }

            Text{
                id:proceedtomaptext
                anchors.top:proceedtomapimagebutton.bottom
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                color:"white"
                text: "Go to Map"
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                width:parent.width
                clip:true
                horizontalAlignment:Text.AlignHCenter
            }

            MouseArea{
                id:proceedbuttoncontainermousearea
                anchors.fill: proceedbuttoncontainer
                enabled: if (!tpkFolder.exists || !gdbfile.exists || !gdbfile2.exists){false}else{true}
                onClicked: {
                    visiblePane = 'mapcontainer'
                    Helper.getAllBldgs()//builds the list used for building search
                }
            }
        }
    }
    //END WELCOMENU
    //---------------------------------------------------------------------------------------------
    //---------------------------------------------------------------------------------------------
    //BEGIN SEARCHMENU
    Rectangle{
        id: searchmenucontainer
        anchors.top: mapcontainer.top
        anchors.bottom: mapcontainer.bottom
        anchors.right: mapcontainer.right
        anchors.left: mapcontainer.left
        color: "pink"
        visible: if (visiblePane === 'searchmenucontainer'){true}else{false}

        Rectangle{
            id: searchmenutopbar
            anchors.top:parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: zoomButtons.width
            color:'grey'
            visible: parent.visible

            Row{
                id: searchmenutopbarrow
                anchors.fill:parent
                spacing: 1

                Rectangle{
                    id: buildingsearchmode
                    color: 'white'  //'red'
                    width: parent.width / 3
                    height: parent.height

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Building")
                        color: "darkblue"
                        font.weight: if(searchmode == 'buildingsearchmode'){Font.Bold}else{Font.Normal}
                    }
                    MouseArea{
                        anchors.fill: parent
                        onClicked: {
                            console.log('Now in buildingsearchmode.')
                            searchmode = 'buildingsearchmode'
                        }
                    }
                }
                Rectangle{
                    id: roomsearchmode
                    width: parent.width / 3
                    height: parent.height
                    color: 'white' //blue'
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Room")
                        color: "darkblue"
                        font.weight: if(searchmode == 'roomsearchmode'){Font.Bold}else{Font.Normal}
                    }
                    MouseArea{
                        anchors.fill: parent
                        onClicked: {
                            console.log('Now in roomsearchmode.')
                            searchmode = 'roomsearchmode'
                            if (allRoomsList.length === 0){
                                Helper.getAllRooms()//builds the list used for room search
                            }
                            else{
                                console.log('allroomslist is already loaded.')
                            }
                        }
                    }
                }
                Rectangle{
                    id: pointsearchmode
                    width: parent.width / 3
                    height: parent.height
                    color:'white' //yellow'
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Point")
                        color: "darkblue"
                        font.weight: if(searchmode == 'pointsearchmode'){Font.Bold}else{Font.Normal}
                    }
                    MouseArea{
                        anchors.fill: parent
                        onClicked: {
                            console.log('Now in pointsearchmode.')
                            searchmode = 'pointsearchmode'
                            //points list can be modified by editing the layer so reload it every time
                            Helper.getAllPoints()//builds the list used for asset point search
                        }
                    }
                }
            }
        }
        Rectangle{
            id:buildingsearchcontainer
            visible: if(searchmode == 'buildingsearchmode'){true}else{false}
            color:'white'  //'red'
            anchors.top:searchmenutopbar.bottom
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.left: parent.left
            border.color: 'grey'
            border.width: 1
            TextField{
                id: searchField
                width: parent.width
                height:zoomButtons.width
                focus: true
                visible: true
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 5
                placeholderText : bldgLyr_nameField
                font.pointSize: 16
                textColor: "black"
                style: TextFieldStyle {
                    textColor: "black"
                    background: Rectangle {
                        radius: 2
                        border.color: "#333"
                        border.width: 1
                    }
                }
                inputMethodHints: Qt.ImhNoPredictiveText //necessary for onTextChanged signal on Android
                onTextChanged: {
                    if(text.length > 0 ) {
                        Helper.reloadFilteredBldgListModel(text);
                    } else {
                        Helper.reloadFullBldgListModel();
                    }
                }
            }
            ListView{
                id:bldglistview
                clip: true
                width: parent.width
                height: parent.height
                anchors.top: searchField.bottom
                model: bldglistmodel
                delegate: bldgdelegate
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
            }

            Component {
                id: bldgdelegate
                Item {
                    width: app.width
                    height: searchField.height
                    anchors.margins: 5
                    Row{
                        spacing: 1
                        width: app.width
                        height: searchField.height
                        anchors.margins: 5
                        Rectangle {
                            width: app.width * 0.8
                            height: searchField.height
                            clip: true
                            Column{
                                Text { text: bldgname; font.pointSize: 14}
                                Text { text: objectid ; visible: false}
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    var foo = objectid //assign to js variable, .geometry seems to only work that way.
                                    map.zoomTo(localBuildingsLayer.featureTable.feature(foo).geometry)
                                    searchField.text = ""
                                    visiblePane = 'mapcontainer'
                                    Helper.updateBuildingDisplay(foo);
                                    Qt.inputMethod.hide();
                                }
                            }
                        }
                        Rectangle{
                            width: app.width * 0.2
                            height: searchField.height
                            Column {
                                Text { width: app.width * 0.2; text: 'List rooms ' + bldgid + '-...'; font.pointSize: 8; color: "darkblue"; verticalAlignment: Text.AlignVCenter; wrapMode: Text.WordWrap;}
                                Text { text: bldgid ; visible: false}
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    searchmode = 'roomsearchmode'
                                    if (allRoomsList.length === 0){
                                        Helper.getAllRooms()//builds the list used for room search
                                    }
                                    roomsearchField.text = bldgid + '-'
                                    Helper.reloadFilteredRoomListModel(bldgid + '-');
                                    roomlistview.positionViewAtBeginning()
                                }
                            }
                        }
                    }
                }
            }
            ListModel{
                id:bldglistmodel
                ListElement {
                    objectid : "objectid"
                    bldgname: "bldgname"
                    bldgid: "bldgid"
                }
            }
            //END buildingsearchcontainer
        }
        Rectangle{
            id:roomsearchcontainer
            visible: if(searchmode == 'roomsearchmode'){true}else{false}
            color:'white'  //'blue'
            anchors.top:searchmenutopbar.bottom
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.left: parent.left
            border.color: 'grey'
            border.width: 1
            TextField{
                id: roomsearchField
                width: parent.width
                height:zoomButtons.width
                focus: true
                visible: true
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 5
                placeholderText : roomLyr_bldgIdField + "-" + roomLyr_roomIdField
                font.pointSize: 16
                textColor: "black"
                style: TextFieldStyle {
                    textColor: "black"
                    background: Rectangle {
                        radius: 2
                        border.color: "#333"
                        border.width: 1
                    }
                }
                inputMethodHints: Qt.ImhNoPredictiveText //necessary for onTextChanged signal on Android
                onTextChanged: {
                    if(text.length > 0 ) {
                        Helper.reloadFilteredRoomListModel(text);
                    } else {
                        Helper.reloadFullRoomListModel();
                    }
                }
            }
            ListView{
                id:roomlistview
                clip: true
                width: parent.width
                height: parent.height
                anchors.top: roomsearchField.bottom
                model: roomlistmodel
                delegate: roomdelegate
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
            }

            Component {
                id: roomdelegate
                Item {
                    width: parent.width
                    height: roomsearchField.height
                    anchors.margins: 5
                    anchors.left: parent.left
                    Column {
                        Text { text: bldgID_dash_roomID; font.pointSize: 16}
                        Text { text: objectid ; visible: false}
                        Text { text: roomID ; visible: false}
                        Text { text: floorID ; visible: false}
                        anchors.left:parent.left
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            //set searchmode so that pointslayer can be queried from map again
                            searchmode = 'buildingsearchmode'

                            var roomObjectID = objectid //assign to js variable, .geometry seems to only work that way.
                            map.zoomTo(localRoomsLayer.featureTable.feature(roomObjectID).geometry)
                            searchField.text = ""

                            //this function sets the definition query so that the correct building
                            // and floor is shown, and highlights the selected room
                            searchFloorID = floorID //used so correct floor can be displayed
                            Helper.updateroomsdisplay(bldgID, floorID);
                            localRoomsLayer.selectFeaturesByIds(0, true)
                            localRoomsLayer.selectFeaturesByIds(objectid, true)
                            roomsearchcallout.visible = true
                            createAnimation.start()
                            roomsearchcallouttext.text = " Room " + roomID + " "

                            visiblePane = 'mapcontainer'

                            //make mobile keybord disappear
                            Qt.inputMethod.hide();
                        }
                    }
                }
            }
            ListModel{
                id: roomlistmodel
                ListElement {
                    objectid : "objectid"
                    roomID: "roomID"
                    floorID : "floorID"
                    bldgID_dash_roomID: "Loading all rooms...please wait."
                    bldgID : "bldgID"
                }
            }
        }//END roomsearchcontainer

        Rectangle{
            id:pointsearchcontainer
            visible: if(searchmode == 'pointsearchmode'){true}else{false}
            color: 'white'
            anchors.top:searchmenutopbar.bottom
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.left: parent.left
            border.color: 'grey'
            border.width: 1
            TextField{
                id: pointsearchField
                width: parent.width
                height:zoomButtons.width
                focus: true
                visible: true
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top:  parent.top
                anchors.margins: 5
                placeholderText : pointsLyr_searchField
                font.pointSize: 16
                textColor: "black"
                style: TextFieldStyle {
                    textColor: "black"
                    background: Rectangle {
                        radius: 2
                        border.color: "#333"
                        border.width: 1
                    }
                }
                inputMethodHints: Qt.ImhNoPredictiveText //necessary for onTextChanged signal on Android
                onTextChanged: {
                    if(text.length > 0 ) {
                        Helper.reloadFilteredPointListModel(text);
                    } else {
                        Helper.reloadFullPointListModel();
                    }
                }
            }
            ListView{
                id:pointlistview
                clip: true
                width: parent.width
                height: parent.height
                anchors.top: pointsearchField.bottom
                model: pointlistmodel
                delegate: pointdelegate
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
            }

            Component {
                id: pointdelegate
                Item {
                    width: parent.width
                    height: searchField.height
                    anchors.margins: 5
                    anchors.left: parent.left
                    Column {
                        Text { text: pointsSearchField ; font.pointSize: 16}
                        Text { text: objectid ; visible: false}
                        Text { text: bldgID ; visible: false}
                        Text { text: floorID ; visible: false}
                        anchors.left:parent.left
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            //set searchmode so that pointslayer can be queried from map again
                            searchmode = 'buildingsearchmode'

                            var pointObjectID = objectid //assign to js variable, .geometry seems to only work that way.
                            map.zoomTo(localPointsLayer.featureTable.feature(pointObjectID).geometry)

                            //update what is shown in the point feature listview
                            Helper.actOnSelectPoints([pointObjectID])

                            searchField.text = ""
                            visiblePane = 'mapcontainer'

                            //this function sets the definition query so that the correct building
                            // and floor is shown, and selects the point
                            searchFloorID = floorID //used so correct floor can be displayed
                            Helper.updateroomsdisplay(bldgID, floorID);

                            //make mobile keybord disappear
                            Qt.inputMethod.hide();
                        }
                    }
                }
            }
            ListModel{
                id: pointlistmodel
                ListElement {
                    objectid : "objectid"
                    floorID : "floorID"
                    pointsSearchField: "Loading all Asset Points...please wait."
                    bldgID : "bldgID"
                }
            }
        }//END POINTSEARCHCONTAINER


    }//END SEARCHMENU
    //---------------------------------------------------------------------------------------------
    //busy indicator activated when user should just wait
    Rectangle{
        id: busyindicatorbackground
        anchors.fill: parent
        color: "white"
        opacity: 0.75
        visible: busyindicator.running
        MouseArea{
            enabled: busyindicator.running
            anchors.fill: parent
            onClicked: console.log("Busy indicator running...")
        }

        //this busyindicator does not show up on Android for some reason. Added Text element so at least something shows up.
        BusyIndicator {
            id: busyindicator
            running: false
            visible: running
            anchors.bottom: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            width: (isLandscape==true) ? parent.height * 0.2 : parent.width * 0.2
            height: width
            onRunningChanged: {
                console.log("busyindicator running changed")
            }
        }
    }
    Text{
        text: "Please wait..."
        anchors.top: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        color: "black"
        font.pointSize: 16
        style: Text.Outline
        styleColor: "white"
        visible: busyindicator.running
    }

    //---------------------------------------------------------------------------------------------
    //once app has fully loaded do ome houekeeping tasks.
    Component.onCompleted: {
        busyindicator.running = true

        visiblePane = 'welcomemenucontainer'

        Helper.addOnlineBasemapChoices([[basemap1_name,basemap1_url],
                                        [basemap2_name,basemap2_url],
                                        [basemap3_name,basemap3_url]])

        if (nextTimeDeleteTPKfile.exists == true){
            tpkFolder.removeFolder()
        }
        else{
            if (tpkFolder.exists){
                tpkFolder.addLayer()
            }
        }

        if (nextTimeDeleteGDBfile.exists == true){
            Helper.deleteGDB()
        }
        else{
            gdbfile.refresh()
            gdb.path = gdbPath //setting this earlier leads to locked gdb file that can't be deleted
            Helper.getAllBldgs()
        }

        if (nextTimeDeleteGDBfile2.exists == true){
            Helper.deleteGDB2()
        }
        else{
            gdbfile2.refresh()
            gdb2.path = gdbPath2 //setting this earlier leads to locked gdb file that can't be deleted
            Helper.getAllBldgs()
        }

        if (gdbfile2.exists){
            console.log("detecting coded value domains for points layer...")
            Helper.detectcodedvaluedomains (localPointsTable,  pointslayerfieldswithdropdowns_json)
            Helper.detectcodedvaluedomains (localRelRecordsTable,  reltablefieldswithdropdowns_json)
        }

        Helper.doorkeeper()
        buttonRotateCounterClockwise.fader.start()
        busyindicator.running = false

        console.log('- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -')
    }
}
