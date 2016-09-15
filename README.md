# AppStudio-Indoor-Points-Editor
## Summary
A configurable [ArcGIS AppStudio](https://appstudio.arcgis.com/) App Template to be used for viewing interior building floor plans and editing an associated points layer with geodatabase attachments and a 1:M related geodatabase table.
+ useable offline
+ building, room, point search
+ leverages OAuth2 authentication with ArcGIS Online
+ configure 1 offline basemap and 3 online alternatives 
+ minimal requirements for data in terms of required fields etc.
+ intuitive user interface
+ points layer is 'floor-aware'. For example, if a building's floor plan is displayed only the points that are located on that floor are displayed on the map. Or if a point is selected via the search menu the correct floorplan is 'overlayed' on the map

![alt text](https://cloud.githubusercontent.com/assets/7443922/14873952/23037e8c-0cc1-11e6-86f9-657286a297b9.PNG "Screen shots of AppStudio-Indoor-Points-Editor on Google Nexus5")


## What you need to use this
+ ArcGIS Online Organizational or Developer account
+ AppStudio for ArcGIS Desktop ("Standard" license, "Basic" is not sufficient) 
+ AppStudio Player app
+ GIS data (Feature Service & Tile Package)

## How to use this
1. Install AppStudio for ArcGIS and sing in to your ArcGIS Online account (you need a "Standard" license allocated to your account to sign in)
2. Download the code in this repo, put the folder "ArcGIS Online or Portal Item ID" (incl. all its contents) into the appropriate directory on your computer. The directory path probably depends on your installation. On Windows by default it is C:\Users\<username>\ArcGIS\AppStudio\Apps\
3. Open AppStudio for Desktop. The new app item will appear now and you can configure the properties (see below) and then upload the app item to your ArcGIS Online account. Alternatively choose the "Create a new app from ..." option.
4. Following that initial upload the id value in your local copy of file itminfo.json (line 16) will have changed to a long string of characters, something like "1234567890ABC123XYZ".
5. Rename the app's folder name in the ...\ArcGIS\AppStudio\Apps\... directory from "arcgis-online-app-item-id-here" to this id value that your upload generated. Depending on how you did step 3 this may not be necessary. (The reason for doing this is so that the app stores the local .geodatabase file in the correct place upon download to device.)
7. Log in to ArcGIS Online, find the Native App item you just uploaded, and register it (type = Multiple, redirect url = urn:ietf:wg:oauth:2.0:oob). This will generate an app id or 'client id'.
8. Enter this client id in MyApp.qml, line 63. Replace the exisitng value for the clientId property with your Native App item's clientId. (This is necessary for OAuth2 authentication to work.)
6. Now "Update" the app item via the AppStudio Upload process. 
9. Use the app on most any device/OS with the AppStudio Player app available in iOS/Android/Windows stores.

## Configurable Properties (for example values look in appinfo.json)
+ Portal or ArcGIS Online URL
  + *The app is designed to work with secured feature services and will ask the user to sign in to the portal specified by this url using OAuth2.*
+ Application clientId
  + *You need to register your application at https://developers.arcgis.com which in turn will provide you with a clientID. Add the following rediect URI to the registered application item: urn:ietf:wg:oauth:2.0:oob* 
+ App Title
  + *The app title is displayed in th title bar.*
+ App Description
  + *The app description is shown on the start screen of the application.* 
+ Basemap Tile Package Item ID
  + *The map uses a tile package as a basemap. The tile package is also used to determine which features from the feature service (see next parameter) are downloaded to the device: only features that intersect the extent of the tile package will be downloaded. The tile package needs to be uploaded to ArcGIS Online and be accessible without authentication (i.e. shared with everyone, not just an ArcGIS Online Group.) Enter the Tile Package's Item ID. Preferrably scale levels should be identical to the ones used by the three onine basemap map services specified below.* 
+ Floor Plans and Buildings Feature Service URL
  + *This feature service needs to contain one polygon layer with building footprints and two layers (lines and polygons) with interior building floor plans. Access to it can be public or can be restricted via ArcGIS Online item sharing properties.* 
+ Building Polygons LayerID
  + *The Feature Service layer ID of the building polygons layer. For example, if the buildings layer is 'on top of' all other layers this parameter should be 0 .* 
+ Floorplan Lines LayerID
  + *The Feature Service layer ID of the floor plan lines layer.* 
+ Buildings layer building name field
+ Buildings layer building ID field
+ Floor plan lines layer building ID field
+ Floor plan lines layer floor field
+ Floor plan lines layer sort field
+ Floorplan Polygons LayerID
  + *The Feature Service layer ID of the floor plan polygons layer.* 
+ Floor plan polygon layer building ID field
+ Floor plan polygon layer floor field
+ Floor plan polygon layer room field
+ Points layer Feature Service URL
  + *This feature service needs to contain one points layer (cordiante system: Web Mercator) with geodatabase attachments enabled, and one geodatabase table (a geodatabase relationship class can exist but is not necessary.) Access to it can be public or can be restricted via ArcGIS Online item sharing properties.* 
+ Points layer building ID field
  + *This points layer attribute field stores the building id with which a point feature is associated. In combination with the parameter below it is used to display on the map only the points located on the currently visible floor. Further, when a new point is created this attribtue will automatically be set to the currently selected building id.* 
+ Points layer floor ID field
  + *This points layer attribute field stores the floor id with which a point feature is associated. In combination with the parameter above it is used to display on the map only the points located on the currently visible floor. Further, when a new point is created this attribtue will automatically be set to the currently selected floor id.* 
+ Points layer search field
  + *The field that the points layer can be search on via the search menu.* 
+ Points layer fields to hide in attribute display
  + *Points layer attribute fields to hide (comma seperated, without spaces). Example: OBJECTID,GlobalID . If you want to show all fields then just leave this parameter blank.* 
+ Points layer foreign key attribute field
  + *The foreign key field in the geodatabase points feature class based on which the point feature can be associated with records form the geodatabase table.* 
+ Related table fields to hide in attribute display
  + *Related table attribute fields to hide (comma seperated, without spaces). Example: OBJECTID,GloabalID,Rel_GobalID . If you want to show all fields then just leave this parameter blank.* 
+ Related table foreign key attribute field
  + *The foreign key field in the geodatabase table based on which the table records can be associated with point features.* 
+ Points layer display title attribute field
  + *One attribute to show in the points ListView.* 
+ Points layer display subtitle field
  + *A second attribute to show in the points ListView.* 
+ Related table display title field
  + *One attribute to show in the related records ListView.* 
+ Related table display subtitle field
  + *A second attribute to show in the related records ListView.* 
+ Online Basemap 1 Label
 + *Name for the first online basemap to show in the basemap picker.* 
+ Online Basemap 1 URL
 + *URL to the first online basemap map service REST endpoint.*
+ Online Basemap 2 Label
+ Online Basemap 2 URL
+ Online Basemap 3 Label
+ Online Basemap 3 URL

Note that the Basemap Tile Package Item needs to be publicly accessible. The floor plans and buildings feature service as well as the Point layer's feature service should be secured and shared through ArcGIS Online Group(s). They need to be sync enabled. The app will download a copy of all features and related records that intersect the tile package's extent.


## Limitations
This is a student project and at this point has several known limitations:
+ Aside from geodatabase maintained fields like OBJECTID etc. it is designed for text fields only.
+ Open text field attribute editing does not validate the length of entered text vs. max. length of field.
+ Subtypes and domains are not supported except for coded value domains. The attribute editing interface will provide a single choice interface listing the domain Codes (e.g. on Windows it will be a drop-down list, on Android as checkboxes, etc.) . I suggest you make domain Codes identical to the domain Descriptions
+ Editor tracking fields are only recognized as such if they are named "created_user", "created_date", "last_edited_user", "last_edited_date". (The default when you enable editor tracking on hosted feature layers.)
+ The feature service of the points layer and basemap tile package has to be in web mercator coordinate system for geometry edits to work
+ Signing in only possible when connected to internet
+ Performance of the search functionality and app in general can be very poor if the room or point feature services contain several thousands of records
