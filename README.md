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
It expects "luneos-components" to be checked out in the folder beside
org.webosports.app.settings: "modules" provides the LuneOS style, and "test/imports"
provides the desktop stand-ins for the LS2 services, so the pages show and keep real
values instead of failing every call.

On Qt 6 the style is named by its module URI rather than by a path, so set this in the
run environment:

```
QT_QUICK_CONTROLS_STYLE=QtQuick.Controls.LuneOS
```

From a terminal the whole thing is:

```
QT_QUICK_CONTROLS_STYLE=QtQuick.Controls.LuneOS qml \
    -I ../luneos-components/test/imports -I ../luneos-components/modules \
    src/qml/main.qml -- --profile=tp
```

The application opens with the category drawer showing; picking an entry switches to
that settings page. "--profile" chooses the device the run pretends to be, which is what
the pages lay themselves out for: "tp" for a TouchPad, "n5" or "gnex" for a phone,
"desktop" for a small window. Every page is meant to work on both, so it is worth trying
a page at a phone size as well as a tablet one.

Services that are not there yet
-------------------------------

Some pages are written against services LuneOS does not have yet. They show a "Not
available on this device" notice rather than offering switches that go nowhere, and come
to life on their own once something answers. docs/missing-services.md lists which pages
those are and the exact contract each one expects, so the service can be written to fit.

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
