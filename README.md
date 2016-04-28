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
3. Open AppStudio for Desktop. The new app item will appear now and you can configure the properties (see below) and then upload the app item to your ArcGIS Online account. 
4. Following that initial upload the id value in your local copy of file itminfo.json (line 16) will have changed to a long string of characters, something like "1234567890ABC123XYZ".
5. Rename the app's folder name in the ...\ArcGIS\AppStudio\Apps\... directory from "arcgis-online-app-item-id-here" to this id value that your upload generated. (The reason for doing this is so that the app stores the local .geodatabase file in the correct place upon download to device)
7. Log in to ArcGIS Online, find the Native App item you just uploaded, and register it (type = Multiple, redirect url = urn:ietf:wg:oauth:2.0:oob). This will generate an app id or 'client id'.
8. Enter this client id in MyApp.qml, line 63. Replace the exisitng value for the clientId property with your Native App item's clientId. (This is necessary for OAuth2 authentication to work.)
6. Now "Update" the app item via the AppStudio Upload process. 
9. Use the app on most any device/OS with the AppStudio Player app available in iOS/Android/Windows stores.

## Configurable Properties (for example values look in appinfo.json)
+ Portal or ArcGIS Online URL
+ Application clientId
+ App Title
+ App Description
+ Basemap Tile Package Item ID
+ Floor Plans and Buildings Feature Service URL
+ Building Polygons LayerID
+ Floorplan Lines LayerID
+ Buildings layer building name field
+ Buildings layer building ID field
+ Floor plan lines layer building ID field
+ Floor plan lines layer floor field
+ Floor plan lines layer sort field
+ Floorplan Polygons LayerID
+ Floor plan polygon layer building ID field
+ Floor plan polygon layer floor field
+ Floor plan polygon layer room field
+ Points layer Feature Service URL
+ Points layer building ID field
+ Points layer floor ID field
+ Points layer search field
+ Points layer fields to hide in attribute display
+ Points layer foreign key attribute field
+ Related table fields to hide in attribute display
+ Related table foreign key attribute field
+ Points layer display title attribute field
+ Points layer display subtitle field
+ Related table display title field
+ Related table display subtitle field
+ Online Basemap 1 Label
+ Online Basemap 1 URL
+ Online Basemap 2 Label
+ Online Basemap 2 URL
+ Online Basemap 3 Label
+ Online Basemap 3 URL

Note that the Basemap Tile Package Item needs to be publicly accessible. The floor plans and buildings feature service as well as the Point layer's feature service should be secured and shared through ArcGIS Online Group(s). They need to be sync enabled. The app will download a copy of all features and relaed records that intersect the tile package's extent.

The configurable fields are used to determine which floors are display-able for each building and which asset points are located on which floor. The requirements for these fields are intentionally kept at a minimum, but it is critical to have these attribute data clean and thus relate-able.

## Limitations
This is a student project and at this point has several known limitations:
+ Aside from geodatabase maintained fields like OBJECTID etc. it is designed for text fields only.
+ Open text field attribute editing does not validate the length of entered text vs. max. length of field.
+ Subtypes and domains are not supported except for coded value domains. The attribute editing interface will provide a single choice interface listing the domain Codes (e.g. on Windows it will be a drop-down list, on Android as checkboxes, etc.) . I suggest you make domain Codes identical to the domain Descriptions
+ Editor tracking fields are only recognized as such if they are named "created_user", "created_date", "last_edited_user", "last_edited_date". (The default when you enable editor tracking on hosted feature layers.)
+ The feature service of the points layer and basemap tile package has to be in web mercator coordinate system for geometry edits to work
+ Signing in (and thus offline editing) only possible when connected to internet
