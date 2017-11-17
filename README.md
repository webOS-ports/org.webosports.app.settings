System Settings
===============

Summary
-------
QML based system settings application for the webOS ports project.

Description
-----------

Usage
-----

Using QtCreator, you can start testing the application by opening "settingsapp.qmlproject".
If you have checked-out "luneos-components" in the folder besides org.webosports.app.settings,
then you can apply the LuneOS style by adding the passing the following argument to qmlscene:

```
-style ../luneos-components/modules/QtQuick/Controls.2/LuneOS
```

Creating a new settings page
----------------------------

Let's suppose you want to add a new setting XXX, corresponding to the
new app org.webosports.app.settings.XXX

This is partially automated. Here are the remaining manual tasks:
* Create a dedicated XXX.qml file in the corresponding folder (General, Connectivity...)
* Eventually create a dedicated icon in images/icons
* Follow the best practices given in Testing/ExamplePage.qml
* Fill in the corresponding entry in the property "categories" of GenericCategoryWindow.qml
* Create the dedicated appinfo.XXX.json file in data/
* Add XXX to the list of "CATEGORY" list in data/CMakeLists.txt

## Contributing

If you want to contribute you can just start with cloning the repository and make your
contributions. We're using a pull-request based development and utilizing github for the
management of those. All developers must provide their contributions as pull-request and
github and at least one of the core developers needs to approve the pull-request before it
can be merged.

Please refer to http://www.webos-ports.org/wiki/Communications for information about how to
contact the developers of this project.
