/*
 * (c) 2017 Christophe Chapuis <chris.chapuis@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 3, as published
 * by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.9
import QtQuick.Controls 2.2

import LunaNext.Common 0.1

ApplicationWindow {
    id: settingsCategoryAppWindow
    visible: true

    readonly property var categories: ({
        "org.webosports.app.settings.example": {
            "source": "Testing/ExamplePage.qml",
            "icon": "Testing/test-category.png",
            "title": "Settings Example"
        },
        "org.webosports.app.settings.wifi": {
            "source": "Connectivity/WiFiPage.qml",
            "icon": "images/icons/icon-wifi.png",
            "title": "WiFi"
        },
       "org.webosports.app.settings.bluetooth": {
           "source": "Connectivity/BluetoothPage.qml",
           "icon": "images/icons/icon-bluetooth.png",
           "title": "Bluetooth"
       },
       "org.webosports.app.settings.about": {
           "source": "General/AboutPage.qml",
           "icon": "images/icons/icon-deviceinfo.png",
           "title": "About"
       }
    })

    property string categoryFile: categories[application.appInfo.id].source
    property string categoryIcon: categories[application.appInfo.id].icon
    property string categoryTitle: categories[application.appInfo.id].title

    property Loader _categoryLoader: categoryLoader  // useful for the tests

    header: CategoryHeader {
        id: categoryHeader
        title: settingsCategoryAppWindow.categoryTitle
        icon: settingsCategoryAppWindow.categoryIcon

        height: Units.gu(10.0)

    }

    background: Rectangle {
        color: "#D8D8D8";
    }

    Loader {
        id: categoryLoader
        anchors.fill: parent
        source: settingsCategoryAppWindow.categoryFile

        property alias actionHeaderComponent: categoryHeader.actionHeaderComponent
        onActionHeaderComponentChanged: console.log("actionHeaderComponent="+actionHeaderComponent);
    }
}
