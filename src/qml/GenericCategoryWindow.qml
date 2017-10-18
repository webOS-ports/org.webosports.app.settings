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

    readonly property var categories: ({
        "org.webosports.app.settings.example": {
            "source": "Testing/ExamplePage.qml",
            "icon": "Testing/test-category.png",
            "title": "Generic Setttings Example"
        },
        "org.webosports.app.settings.wifi": {
            "source": "Connectivity/WiFiPage.qml",
            "icon": "images/wifi/wifi-category.png",
            "title": "WiFi"
        },
       "org.webosports.app.settings.bluetooth": {
           "source": "Connectivity/BluetoothPage.qml",
           "icon": "images/wifi/wifi-category.png",
           "title": "Bluetooth"
       },
       "org.webosports.app.settings.about": {
           "source": "General/AboutPage.qml",
           "icon": "images/General/about-category.png",
           "title": "About"
       }
    })

    property alias categoryFile: categoryLoader.source
    property alias categoryIcon: categoryHeader.icon
    property alias categoryTitle: categoryHeader.title

    property Loader _categoryLoader: categoryLoader  // useful for the tests

    header: CategoryHeader {
        id: categoryHeader
        title: "System Settings"
        icon: "images/icon.png"

        height: Units.gu(10.0)

    }

    background: Rectangle {
        color: "#D8D8D8";
    }

    Loader {
        id: categoryLoader
        anchors.fill: parent

        property alias actionHeaderComponent: categoryHeader.actionHeaderComponent
        onActionHeaderComponentChanged: console.log("actionHeaderComponent="+actionHeaderComponent);
    }

    Component.onCompleted: {
        settingsCategoryAppWindow.categoryFile = categories[application.appId].source;
        settingsCategoryAppWindow.categoryIcon = categories[application.appId].icon;
        settingsCategoryAppWindow.categoryTitle = categories[application.appId].title;
    }
}
