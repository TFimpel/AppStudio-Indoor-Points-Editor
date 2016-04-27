//function detects coded attribute domains in points layer and build pointslayerfieldswithdropdowns object.
//This should be called (1)after every sync (becasue may have changed in parent .gdb) and (2)if geodatabase already exists on app load
function detectcodedvaluedomains (geodatabasefeaturetable, fieldswithdropdownsobject_to_build){
    console.log("now running detectcodedvaluedomains")
    //remove all existing properties in case this has changed between syncs
    for (var property in fieldswithdropdownsobject_to_build) delete  fieldswithdropdownsobject_to_build[property];
    var editableAttributeFields = geodatabasefeaturetable.editableAttributeFields
    var numberoffields = editableAttributeFields.length
    for (var i = 0; i < numberoffields; i++) {
        var field = editableAttributeFields[i].json
        if(field.hasOwnProperty("domain")){
            var fieldname = field['name']
            var domain = field['domain']
            //add empty string as default value for every field. Becasue we're not leveraging feature templates to create features newly inserted features should have no default values.
            var codedvalueslist = [""]
            for (var d = 0; d < domain['codedValues'].length; d++) {
                codedvalueslist.push(domain['codedValues'][d]['code'])
            }
            fieldswithdropdownsobject_to_build[fieldname] = codedvalueslist
        }
    }
    console.log('fieldswithdropdownsobject_to_build:')
    console.log(JSON.stringify(fieldswithdropdownsobject_to_build))
}


//function to populate the fieldslistview with the point layer's attribute fields and drop-down lists
function getFields( featureLayer, hitFeatureId ) {
    fieldsModel.clear();
    var dropdownlists = pointslayerfieldswithdropdowns_json
    var fieldsCount = featureLayer.featureTable.fields.length;
    for ( var f = 0; f < fieldsCount; f++ ) {
        var fieldName = featureLayer.featureTable.fields[f].name;
        //exclude the shapefield, we dont want to show that in the attribute fieldslistview
        if ( fieldName !== "Shape" ) {
            //only include fields that are not in pointslayer_hideFields config. parameter
            var isShownField =  isFieldShown(pointsLyr_hideFields, fieldName)
            if (isShownField){
                //check if the field should have a drop-down list, if not make it a text field
                var fieldwithdropdown = isDropDownfield(fieldName,  pointslayerfieldswithdropdowns_json)
                if (fieldwithdropdown == false){
                    console.log('no drop down for field ' + fieldName)
                    var attrValue =  featureLayer.featureTable.feature(hitFeatureId).attributeValue(fieldName);
                    if (attrValue == null){
                        fieldsModel.append({"name": fieldName,"choices": "", "string": "", "fieldtype": "opentext"});
                    }
                    else {
                        //if it is the an editor tracking date field show the value formatted as UTC string, otherwise show the attribute value as a string
                        var attrString = (fieldName=='created_date' | fieldName =='last_edited_date' ) ? (new Date(attrValue).toUTCString()) : attrValue.toString()
                        fieldsModel.append({"name": fieldName,"choices":  "", "string": attrString , "fieldtype": "opentext"});
                    }
                }
                //if it does have a drop down list make it a combobox, add the possibe choices, and if the field has a value then set currentIndex of the drop down list
                if (fieldwithdropdown == true){
                    console.log('build drop down for field ' + fieldName)
                    var dropdownvalueslist = getDropDownValues(fieldName, pointslayerfieldswithdropdowns_json)
                    var dropdownvalues = dropdownvalueslist.toString()
                    var attrValue = featureLayer.featureTable.feature(hitFeatureId).attributeValue(fieldName);
                    if (attrValue == null){
                        fieldsModel.append({"name": fieldName, "choices": dropdownvalues, "string": "", "fieldtype": "dropdown"});
                    }
                    else {
                        var attrString = attrValue.toString()
                        var currentIndex = (dropdownvalueslist.indexOf(attrString)).toString();
                        fieldsModel.append({"name": fieldName, "choices": dropdownvalues, "string": currentIndex,"fieldtype": "dropdown"});
                    }
                }
                //here we could add additional if-else logic to allow for other field types (date, decimal, or integer).
            }
        }
    }
}


//function to populate the attribute name and values for the related table
function getRelTableFields( featureTable, relatedRecordID ) {
    relTableFieldsModel.clear();
    var dropdownlists = reltablefieldswithdropdowns_json
    var fieldsCount = featureTable.fields.length;
    for ( var f = 0; f < fieldsCount; f++ ) {
        var fieldName = featureTable.fields[f].name;
        //only include fields that are not in relTable_hideFields config. prameter
        var isShownField =  isFieldShown(relTable_hideFields, fieldName)
        if (isShownField){
            //check if the field should have a drop-down list, if not make it an open text field
            var fieldwithdropdown = isDropDownfield(fieldName, reltablefieldswithdropdowns_json)
            if (fieldwithdropdown == false){
                console.log('no drop down for field ' + fieldName)
                var attrValue = featureTable.feature(relatedRecordID).attributeValue(fieldName);
                if (attrValue == null){
                    relTableFieldsModel.append({"name": fieldName,"choices": "", "string": "", "fieldtype": "opentext"});
                }
                else {
                    //if it is the an editor tracking date field show the value formatted as UTC string, otherwise show the attribute value as a string
                    var attrString = (fieldName=='created_date' | fieldName =='last_edited_date' ) ? (new Date(attrValue).toUTCString()) : attrValue.toString()
                    relTableFieldsModel.append({"name": fieldName,"choices":  "", "string": attrString , "fieldtype": "opentext"});
                }
            }
            //if it does have a drop down list make it a combobox, add the possibe choices, and if the field has a value then set currentIndex of the drop down list
            if (fieldwithdropdown == true){
                console.log('build drop down for field ' + fieldName)
                var dropdownvalueslist = getDropDownValues(fieldName, reltablefieldswithdropdowns_json)
                var dropdownvalues = dropdownvalueslist.toString()
                var attrValue = featureTable.feature(relatedRecordID).attributeValue(fieldName);
                if (attrValue == null){
                    relTableFieldsModel.append({"name": fieldName, "choices": dropdownvalues, "string": "", "fieldtype": "dropdown"});
                }
                else {
                    var attrString = attrValue.toString();
                    var currentIndex = (dropdownvalueslist.indexOf(attrString)).toString();
                    relTableFieldsModel.append({"name": fieldName, "choices": dropdownvalues, "string": currentIndex,"fieldtype": "dropdown"});
                }
            }
            //here we could add additional if-else logic to allow for other field types (date, decimal, or integer).
        }
    }
}

//function is called when attribute updates to a related table record should be saved to the .geodatabase.
//fuction iterates over the field name and value pairs in the listview and then executes .updateFeature
function updateRelatedRecord(editedRelatedFeatureID){
    console.log('now running updateRelatedRecord')
    var featureToEdit = localRelRecordsTable.feature(editedRelatedFeatureID);
    for (var i = 0; i <  relTableFieldsColumn.children.length - 1; ++i){  //note add the -1 here becasue the last element is not a row but a repeater...not sure why, maybe that's how repeaters and columns work.
        var fieldName = relTableFieldsColumn.children[i].children[0].text //this gets the nameLabel
        var opentextfieldvalue = relTableFieldsColumn.children[i].children[1].text //this gets the valueEdit from the open text field
        var dropdownlistfieldvalue = relTableFieldsColumn.children[i].children[2].currentText //this gets the selected choice from a drop down list

        //determine the value by checking whether it was an open text field or a field with a drop down list
        var fieldValue
        if (relTableFieldsColumn.children[i].children[1].visible == true){
            fieldValue = opentextfieldvalue
        }
        if (relTableFieldsColumn.children[i].children[2].visible == true){
            fieldValue = dropdownlistfieldvalue
        }
        featureToEdit.setAttributeValue(fieldName , fieldValue);
    }
    console.log(JSON.stringify((featureToEdit.json)))
    localRelRecordsTable.updateFeature(editedRelatedFeatureID, featureToEdit)
}

//function tests if a given field has an attribute domain associated with it. Returns a boolean.
function isDropDownfield(fieldname, fieldswithdropdowns_json){
    console.log('now running isDropDownfield')
    var listoffieldswithdropdowns = Object.keys(fieldswithdropdowns_json)
    if ((listoffieldswithdropdowns.indexOf(fieldname)) > -1){
        console.log(fieldname + ' has a dropdown')
        return true
    }
    else{
        console.log(fieldname + ' has no dropdown')
        return false
    }
}

//function gets the possible values for a field from the fieldswithdropdowns_json object. returns a list of teh possible values.
function getDropDownValues (fieldname, fieldswithdropdowns_json){
    console.log('now running getDropDownValues')
    var dropdownvalueslist = fieldswithdropdowns_json[fieldname]
    console.log(dropdownvalueslist)
    return dropdownvalueslist
}




//function adds list of basemap choices to the model of the basemaplistview
function addOnlineBasemapChoices(l){
    console.log('now running addOnlineBasemapChoices')
    basemapList.model.clear()
    basemapList.model.insert(0, {"name": "  Default  ", "url":tpkfilepath}); //tpkfilepath is initally empty string and is built when tkp layer is added first time
    basemapList.currentIndex  = 0;
    for( var i=0; i < l.length ; ++i ){
        var name = l[i][0]
        var url = l[i][1]
        console.log(name)
        console.log(url)
        basemapList.model.append({'name': name,
                                     'url': url
                                 })
    }
}

//function is called when one or more points are selected either from map or form search menu.
//querying the points table triggers execution of further functions.
function actOnSelectPoints(features){
    console.log('now running actOnSelectPoints')
    localPointsLayer.selectFeaturesByIds(0,false)//unselect any selected feature
    featureDetailsPane.visible = false;
    editingMode= 'none';
    sideOrBottomPaneContainerState = 'expanded'
    baseQuery.where = "OBJECTID = ''"
    for ( var i = 0; i < features.length; i++ ) {
        var featureId = features[i];
        baseQuery.where = baseQuery.where + (' OR OBJECTID = '+ featureId)
    }
    localPointsTable.queryFeatures(baseQuery);
}

//function is called when text in searchbox of point search menu changes
//it's purose is to filter the point features shown in the point search menu's listview
function reloadFilteredPointListModel(pointsSearchField) {
    console.log('now running reloadFilteredRoomListModel')
    pointlistmodel.clear();
    for( var i=0; i < allPointsList.length ; ++i ) {
        if (allPointsList[i][1].toLowerCase().indexOf(pointsSearchField.toLowerCase()) >= 0){
            pointlistmodel.append({"pointsSearchField" : allPointsList[i][1],
                                      "bldgID" : allPointsList[i][2],
                                      "floorID" : allPointsList[i][3],
                                      "objectid" : allPointsList[i][0]})
        };
    }
}

//function is called when text in searchbox of point search menu changes to an empty string
//it's purose is to load all of the point features into the point search menu's listview
function reloadFullPointListModel(){
    console.log('now running reloadFullPointListModel. allPointsList.length is ' + (allPointsList.length).toString())
    pointlistmodel.clear();
    for( var i=0; i < allPointsList.length ; ++i ) {
        console.log(allPointsList[i][1])
        pointlistmodel.append({"pointsSearchField" : allPointsList[i][1],
                                  "bldgID" : allPointsList[i][2],
                                  "floorID" : allPointsList[i][3],
                                  "objectid" : allPointsList[i][0]})
    }
}

//this function queries the points layer for all points
function getAllPoints(){
    localPointsTable.queryFeatures("OBJECTID > 0");
}

//this function reads all the asset points form the iterator that is returned by the table into a list for point search
//include information on which building and floor the point is associated with so that that floor can be shown on the map then.
function buildAllPointsList(iterator){
    console.log('now running buildAllPointsList')
    allPointsList = [];
    while (iterator.hasNext()) {
        var feature = iterator.next();
        var objectID = (feature.attributeValue("OBJECTID").toString())
        var bldgID = (feature.attributeValue(pointsLyr_bldgIdField))
        var foorID = (feature.attributeValue(pointsLyr_floorIdField))
        var pointsSearchField = (feature.attributeValue(pointsLyr_searchField))
        allPointsList.push([objectID, pointsSearchField, bldgID, foorID]);
    }
    //sort alphabetically by point search field
    allPointsList.sort(compareBySecondArrayElement)
    //then load it into the model
    reloadFullPointListModel()
}


//function sets the index of the floor list. It is called when a point is selected via the point search menu.
function setFloorLitIndexAfterSearch(searchFloorID){
    if (searchFloorID != ''){
        for (var i=0; i < floorListView.model.count; i++){
            if (searchFloorID === floorListView.model.get(i).Floor){
                floorListView.currentIndex = 0
                floorListView.currentIndex =  i
            }
        }
    }
}

//function filters the floor lines and polygons as well as the points lyer to only show features associated with a given floorID
function setFloorFiltersByFloorID(floorID){
    console.log('now running setFloorFiltersByFloorID with floorID ' + floorID)
    localLinesLayer.definitionExpression = lineLyr_floorIdField  + " = '"+floorID+"'" + " AND " + lineLyr_bldgIdField + "= '" + currentBuildingID +"'"
    localRoomsLayer.definitionExpression = roomLyr_floorIdField  + " = '"+floorID+"'" + " AND " + roomLyr_bldgIdField + "= '" + currentBuildingID +"'"

    //added to filter the asset points layer to only show the points located on the selected floor
    localPointsLayer.definitionExpression = pointsLyr_floorIdField  + " = '"+floorID+"'" + " AND " + pointsLyr_bldgIdField + "= '" + currentBuildingID +"'"
    map.refresh()
}

//function does small tasks like setting the infocontainer text and calls other functions necessary for displaying a given floor
function updateroomsdisplay(bldgID, floorID){
    console.log('now running  updateroomsdisplay')
    infocontainer.visible = true;

    //get the buildingslayer objectid, bldgname, bldgid, then get the building level things set
    var getBuildingObjectIDResults = getBuildingObjectID(bldgID, allBlgdList) //returns list [blgdobjectid, bldgname, bldgid]

    //if this is called from the point search and the point is not associated with a building do this
    if (getBuildingObjectIDResults === ['','','']){
        currentBuildingID = ''
        localBuildingsLayer.clearSelection();
        currentBuildingObjectID = ''
        infotext.text = ''
        hideAllFloors()
    }
    //otherwise if the point has a building and floor associated with it do this
    else{
        currentBuildingID = bldgID
        localBuildingsLayer.clearSelection();
        currentBuildingObjectID = getBuildingObjectIDResults[0]
        localBuildingsLayer.selectFeature(currentBuildingObjectID);
        var bldgName = getBuildingObjectIDResults[1]
        var bldgNumber = currentBuildingID
        infotext.text = bldgName + " (#" + bldgNumber + ")"

        //trigger the foor slider to refresh
        localLinesTable.queryFeatures("OBJECTID > 0")//this will trigger the populate floor slider functionailty

        //set the definition query on the rooms and walls layer and set the index on the floor slider to the correct position
        setFloorFiltersByFloorID(floorID)
    }
}

//----------------------------------------------------------------------
//load a filtered rooms into the litview shown in the search menu
function reloadFilteredRoomListModel(bldgID_dash_roomID) {

    console.log('now running reloadFilteredRoomListModel allRoomsList.length is ' + (allRoomsList.length).toString())
    roomlistmodel.clear();
    for( var i=0; i < allRoomsList.length ; ++i ) {

        //.startsWith likely faster that .indexOf but not supported in qml
        //if (allRoomsList[i][4].startsWith(bldgID_dash_roomID)){

        if (allRoomsList[i][4].indexOf(bldgID_dash_roomID) >= 0){
            roomlistmodel.append({"bldgID" : allRoomsList[i][1],
                                     "floorID" : allRoomsList[i][2],
                                     "roomID" : allRoomsList[i][3],
                                     "bldgID_dash_roomID": allRoomsList[i][4],
                                     "objectid" : allRoomsList[i][0]})
        };
        if (i == allRoomsList.length){
            busyindicator.running = false
        }
    }
}



//used for building a list of all rooms.
//list is stored as a global variable queried via the search menu.
function getAllRooms(){
    localRoomsTable.queryFeatures("OBJECTID > 0");
}
function buildAllRoomsList(iterator){
    console.log('now running buildAllRoomsList')
    allRoomsList = [];
    while (iterator.hasNext()) {
        var feature = iterator.next();
        var objectID = (feature.attributeValue("OBJECTID").toString())
        var bldgID = (feature.attributeValue(roomLyr_bldgIdField))
        var foorID = (feature.attributeValue(roomLyr_floorIdField))
        var roomID = (feature.attributeValue(roomLyr_roomIdField))
        var bldgID_dash_roomID = bldgID + '-' + roomID
        allRoomsList.push([objectID, bldgID, foorID, roomID, bldgID_dash_roomID]);
    }
    //sort alphabetically by building id
    allRoomsList.sort(compareBySecondArrayElement)
    //load them into the model
    reloadFullRoomListModel()
}


//this is run when room search mode is selected or when room search menau seach field is set back to empty text
function reloadFullRoomListModel(){
    console.log('now running reloadFullRoomListModel. allRoomsList.length is ' + (allRoomsList.length).toString())
    roomlistmodel.clear();
    for( var i=0; i < allRoomsList.length ; ++i ) {
        roomlistmodel.append({"bldgID" : allRoomsList[i][1],
                                 "floorID" : allRoomsList[i][2],
                                 "roomID" : allRoomsList[i][3],
                                 "bldgID_dash_roomID": allRoomsList[i][4],
                                 "objectid" : allRoomsList[i][0]})
    }
    if (i == allRoomsList.length){
        busyindicator.running = false
    }
}

function buildSelectedRelRecordsList(iterator){
    console.log('now running Helper.buildSelectedRelRecordsList')
    relRecordsList.model.clear()
    while (iterator.hasNext()) {
        var feature = iterator.next();
        var objectID = feature.attributeValue("OBJECTID").toString()
        var relTableListView_titlefield1Value = feature.attributeValue(relTableListView_titlefield1)
        var relTable_fkFieldValue = feature.attributeValue(relTable_fkField).toString()
        var relTableListView_titlefield2Value = feature.attributeValue(relTableListView_titlefield2)
        console.log('appending relate record: '+ objectID + ' '+ relTableListView_titlefield1Value + ' '+relTable_fkFieldValue)
        relRecordsList.model.insert(0,{"object_id" : objectID,
                                        "relTableListView_titlefield1Value" : relTableListView_titlefield1Value,
                                        "relTable_fkFieldValue" : relTable_fkFieldValue,
                                        "relTableListView_titlefield2Value" :relTableListView_titlefield2Value
                                    })
    }

    /*
    //below logic did not build a nested list. i don't know why. advantage of building list and then appending lsit tomodel is that we can sort the lsit prior to appending to model.
    var relatedRecords = [];
    while (iterator.hasNext()) {
         var feature = iterator.next();
         var objectID = feature.attributeValue("OBJECTID").toString()
         var relTableListView_titlefield1Value = feature.attributeValue(relTableListView_titlefield1)
         var relTable_fkFieldValue = feature.attributeValue(relTable_fkField).toString()
         var relTableListView_titlefield2Value = feature.attributeValue(relTableListView_titlefield2)

        relatedRecords.push([objectID,relTableListView_titlefield1Value,relTableListView_titlefield2Value,relTable_fkFieldValue]);
        //relRecords.push(["1","2","3","4"]);
        console.log(relatedRecords)
   }
    console.log('relatedRecords: ')
    console.log(relatedRecords)
    //sort them so that if add new record it appears at the top
    //relRecords.sort(compareByFirstArrayElement)
    //relRecords.reverse();
    //console.log('relRecords: ')
    //console.log(relRecords)

    relRecordsList.model.clear()
    for( var i=0; i < relatedRecords.length ; ++i ) {
    console.log('relRecordsList.model.append:')
    console.log(relatedRecords[i][0])
        console.log(relatedRecords[i][2])
        console.log(relatedRecords[i][1])
        console.log(relatedRecords[i][3])
    relRecordsList.model.append({"object_id" : relatedRecords[i][0],
                          "relTableListView_titlefield1Value" : relatedRecords[i][1],
                           "relTable_fkFieldValue" : relatedRecords[i][2],
                            "relTableListView_titlefield2Value" :relatedRecords[i][3]
                           })
     console.log(i)
}
*/
}

//takes a string  formatted like this "OBJECTID,GlobalID" and a field name and returns true if the field name is not
//one of th comma seperated strings. Used for functionality of hiding certain fields via app parammeter
function isFieldShown(string, fieldName){
    var array = string.split(',');
    var isShownField = (array.indexOf(fieldName) < 0)
    return isShownField
}

//function loads selected point features into the points list view
function buildSelectedPointsList(iterator){
    var pointsList = []
    while (iterator.hasNext()) {
        var feature = iterator.next();
        var objectID = (feature.attributeValue("OBJECTID").toString())
        var pointsLyr_fkFieldValue = (feature.attributeValue(pointsLyr_fkField))
        var pointsListView_titlefield1Value = (feature.attributeValue(pointsListView_titlefield1))
        var pointsListView_titlefield2Value =(feature.attributeValue(pointsListView_titlefield2))
        var pointsListView_bldgValue = (feature.attributeValue(pointsLyr_bldgIdField))
        var pointsListView_floorValue = (feature.attributeValue(pointsLyr_floorIdField))
        var nextPoint = [objectID  , pointsListView_titlefield1Value , pointsListView_titlefield2Value , pointsLyr_fkFieldValue, pointsListView_bldgValue, pointsListView_floorValue]
        pointsList.push(nextPoint);
    }
    pointslistmodel.clear();
    for( var i=0; i < pointsList.length ; ++i ) {
        pointslistmodel.append({"object_id" : pointsList[i][0],
                                   "pointsLyr_fkFieldValue" : pointsList[i][3],
                                   "pointsListView_titlefield1Value" : pointsList[i][1],
                                   "pointsListView_titlefield2Value" :pointsList[i][2],
                                   "pointsListView_bldgValue":  pointsList[i][4],
                                   "pointsListView_floorValue": pointsList[i][5]
                               })

        //start with fist list element selected
        pointslistview.currentIndex = 0
        //select the point on the map that is associated with the selected list item
        editedFeatureID = pointslistmodel.get(pointslistview.currentIndex).object_id
        localPointsLayer.selectFeaturesByIds(editedFeatureID, false)
    }}


//------------------------------------------------------------------------------
//used for deleting the runtime geodatabases
function deleteGDB(){
    syncLogFolder.removeFolder(syncLogFolder.path, true);
}
function deleteGDB2(){
    syncLogFolder2.removeFolder(syncLogFolder2.path, true);
}


//--------------------------------------------------------------------------
//used for building a list of all buldings.
//list is stored as a global variable queried via the search menu.
function getAllBldgs(){
    localBuildingsTable.queryFeatures("OBJECTID > 0");
}
function buildAllBlgdList(iterator){
    allBlgdList = [];
    while (iterator.hasNext()) {
        var feature = iterator.next();
        var objectID = (feature.attributeValue("OBJECTID").toString())
        var bldgID = (feature.attributeValue(bldgLyr_bldgIdField))
        var bldgName = (feature.attributeValue(bldgLyr_nameField))
        allBlgdList.push([objectID, bldgName, bldgID]);
    }
    //sort alphabetically by building name
    allBlgdList.sort(compareBySecondArrayElement)
}

//----------------------------------------------------------------------
//load all buildings into the litview shown in the search menu
function reloadFullBldgListModel(){
    bldglistmodel.clear();
    for( var i=0; i < allBlgdList.length ; ++i ) {
        bldglistmodel.append({"bldgname" : allBlgdList[i][1],
                                 "objectid" : allBlgdList[i][0],
                                 "bldgid" : allBlgdList[i][2]})
    }
}

//----------------------------------------------------------------------
//load a filtered buildings into the litview shown in the search menu
function reloadFilteredBldgListModel(bldgname) {
    bldglistmodel.clear();
    for( var i=0; i < allBlgdList.length ; ++i ) {
        if (allBlgdList[i][1].toLowerCase().indexOf(bldgname.toLowerCase()) >= 0){
            bldglistmodel.append({"bldgname" : allBlgdList[i][1],
                                     "objectid" : allBlgdList[i][0],
                                     "bldgid" : allBlgdList[i][2]})
        };
    }
}

//--------------------------------------------------------------------------------
//hide all floors from map display and show all points.
function hideAllFloors(){
    floorListModel.clear()
    localRoomsLayer.definitionExpression = "OBJECTID < 0"
    localLinesLayer.definitionExpression = "OBJECTID < 0"

    //when no floor is selected all points should show
    localPointsLayer.definitionExpression = "OBJECTID > 0"
}

//----------------------------------------------------------------------
//function used for sorting nested arrays by their second element
function compareBySecondArrayElement(a, b) {
    if (a[1] === b[1]) {
        return 0;
    }
    else {
        return (a[1] < b[1]) ? -1 : 1;
    }
}
//----------------------------------------------------------------------
//function used for sorting nested arrays by their first element
function compareByFirstArrayElement(a, b) {
    if (a[0] === b[0]) {
        return 0;
    }
    else {
        return (a[0] < b[0]) ? -1 : 1;
    }
}

//-----------------------------------------------------------------------
//used for populating the floor slider and displaying only one floor at a time, given the index of the selected floor in the floorlistview
function setFloorFilters(index){
    localLinesLayer.definitionExpression = lineLyr_floorIdField  + " = '"+(floorListModel.get(floorListView.currentIndex).Floor)+"'" + " AND " + lineLyr_bldgIdField + "= '" + currentBuildingID +"'"
    localRoomsLayer.definitionExpression = roomLyr_floorIdField  + " = '"+(floorListModel.get(floorListView.currentIndex).Floor)+"'" + " AND " + roomLyr_bldgIdField + "= '" + currentBuildingID +"'"

    //added this for asset points layer
    localPointsLayer.definitionExpression = pointsLyr_floorIdField  + " = '"+(floorListModel.get(floorListView.currentIndex).Floor)+"'" + " AND " + pointsLyr_bldgIdField + "= '" + currentBuildingID +"'"
}

//function populates the floor listview given the building and iterator of floors
function populateFloorListView(iterator, bldg, sortField){
    floorListModel.clear();
    var floorlist = [];
    while (iterator.hasNext()) {
        var feature = iterator.next();
        if (feature.attributeValue(lineLyr_bldgIdField) === bldg){
            var floorValue = feature.attributeValue(lineLyr_floorIdField);
            var sortValue = feature.attributeValue(sortField);
            floorlist.push([floorValue, sortValue]);
        }
    }
    floorlist.sort(compareBySecondArrayElement);
    for( var i=0; i < floorlist.length ; ++i ) {
        floorListModel.append({"Floor" : floorlist[i][0]})
    };
    if (floorlist.length > 0){
        floorcontainer.visible = true;
    }
    //if there are no floors for seleted building hide the slider
    else{
        floorcontainer.visible = false;
    }

    if (searchFloorID != ''){
        setFloorLitIndexAfterSearch(searchFloorID)
    }
    else{
        //initially display the "lowest" floor in a building
        floorListView.currentIndex = 0
        setFloorFilters(0);
    }
}

//------------------------------------------------------------------------------
//function used for "housekeeping" tasks. takes actions based on whether user already has local copies of tpk and gdb on device.
function doorkeeper(){

    //required to corectly report the last time synced
    if (updatesCheckfile.exists) {updatesCheckfile.refresh()};
    if (updatesCheckfile2.exists) {updatesCheckfile2.refresh()};

    if (gdbfile.exists){
        gdbfile.refresh()
    };
    if (gdbfile2.exists){
        gdbfile2.refresh()
    };
    if (tpkfile.exists){tpkfile.refresh()};

    if (gdbfile.exists && updatesCheckfile.exists) {
        gdbinfobuttontext.text = " Sync updates for floor plan layers. Last updates downloaded " + updatesCheckfile.lastModified.toLocaleString("MM.dd.yyyy hh:mm ap") + "."
    }
    if (gdbfile.exists && !updatesCheckfile.exists) {
        gdbinfobuttontext.text = " Sync updates for floor plan layers. App is unable to determine when updates were last synced."
    }
    //check gdbDeleteButtonText.text === "Undo" becasue nextTimeDeleteGDBfile.exists always evaluates to false for some reason(?)
    if (gdbDeleteButtonText.text === "Undo"){
        gdbinfobuttontext.text = '<b><font color="red"> Device copy of operational layers set to be removed next time app is opened. </font><\b>'
    }

    if (gdbfile2.exists && updatesCheckfile2.exists) {
        gdbinfobuttontext2.text = " Sync updates for asset point layer. Last synced " + updatesCheckfile2.lastModified.toLocaleString("MM.dd.yyyy hh:mm ap") + "."
    }
    if (gdbfile2.exists && !updatesCheckfile2.exists) {
        gdbinfobuttontext2.text = " Sync updates for asset point layer. App is unable to determine when updates were last synced."
    }
    //check gdbDeleteButtonText2.text === "Undo" becasue nextTimeDeleteGDBfile.exists always evaluates to false for some reason(?)
    if (gdbDeleteButtonText2.text === "Undo"){
        gdbinfobuttontext2.text = '<b><font color="red"> Device copy of point layer set to be removed next time app is opened. </font><\b>'
    }


    //this text is better set with this js function instead of putting the property on watch because the tpk download also modifies it
    if (!tpkFolder.exists){
        tpkinfobuttontext.text = " Download the basemap tile package to be able to proceed. "
    }
    else {tpkinfobuttontext.text = " Offline basemap tile package last downloaded to this device " + tpkfile.lastModified.toLocaleString("MM.dd.yyyy hh:mm ap") + "."
    }
}

//----------------------------------------------------------------------
//if the building is not currenty selected then update the infotext and trigger a querychange on the lines and rooms tables
function selectBuildingOnMap(x,y) {
    var featureIds = localBuildingsLayer.findFeatures(x, y, 1, 1);
    if (featureIds.length > 0) {
        updateBuildingDisplay(featureIds[0])
    }
}

//function is executed when a building is selected. triggers subsequent function by querying the floor plan lines table
function updateBuildingDisplay(selectedFeatureId){
    infocontainer.visible = true;
    if (currentBuildingObjectID != selectedFeatureId){

        //if new building is selected unselect highlighted room
        searchFloorID = '';
        localRoomsLayer.selectFeaturesByIds(0, false)

        localBuildingsLayer.clearSelection();
        localBuildingsLayer.selectFeature(selectedFeatureId);
        hideAllFloors();
        currentBuildingObjectID = selectedFeatureId
        console.log(selectedFeatureId)
        var bldgName = localBuildingsLayer.featureTable.feature(selectedFeatureId).attributeValue(bldgLyr_nameField)
        var bldgNumber = localBuildingsLayer.featureTable.feature(selectedFeatureId).attributeValue(bldgLyr_bldgIdField)
        infotext.text = bldgName + " (#" + bldgNumber + ")"
        currentBuildingID = bldgNumber
        localLinesTable.queryFeatures("OBJECTID > 0")//this will trigger the populate floor slider functionailty
    }
}

//----------------------------------------------------------------------
//for keeping track when the offline geodatabases have been synced last
function writeSyncLog(){
    syncLogFolder.writeFile("syncLog.txt","Offline Geodatabase last synced with server when this file was last modified. Very basic but hey, no annoying file locking issues...it just works")
}
function writeSyncLog2(){
    syncLogFolder2.writeFile("syncLog2.txt","Offline Geodatabase last synced with server when this file was last modified. Very basic but hey, no annoying file locking issues...it just works")
}


//finds the objectid for a given building by iterating over the allbuidinglist
function getBuildingObjectID(buidingID, buidlingList){
    for( var i=0; i < allBlgdList.length ; ++i ) {
        var blgdobjectid = allBlgdList[i][0]
        var bldgname = allBlgdList[i][1]
        var bldgid = allBlgdList[i][2]
        if (bldgid === buidingID){
            console.log('getBuildingObjectID returned ' + [blgdobjectid, bldgname, bldgid])
            return [blgdobjectid, bldgname, bldgid]
        }
        if (i === allBlgdList.length-1){
            console.log('getBuildingObjectID  was unable to find a building associated with this point.')
            return ['','','']
        }
    }
};
