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
import Eos.Window 0.1

WebOSWindow {
    id: settingsCategoryAppWindow
    visible: true

    readonly property var categories: ({
        "org.webosports.app.settings.example": {
            "source": "Testing/ExamplePage.qml",
            "icon": "Testing/test-category.png",
            "title": "Settings Example"
        },
        "org.webosports.app.settings.bluetooth": {
            "source": "Connectivity/BluetoothPage.qml",
            "icon": "images/icons/icon-bluetooth.png",
            "title": "Bluetooth"
        },
       "org.webosports.app.settings.networksettings": {
            "source": "Connectivity/NetworkSettingsPage.qml",
            "icon": "images/icons/icon-networksettings.png",
            "title": "Network Settings"
        },
        "org.webosports.app.settings.vpn": {
            "source": "Connectivity/VPNPage.qml",
            "icon": "images/icons/icon-vpn.png",
            "title": "VPN (placeholder)"
        },
        "org.webosports.app.settings.wifi": {
            "source": "Connectivity/WiFiPage.qml",
            "icon": "images/icons/icon-wifi.png",
            "title": "Wi-Fi"
        },
        "org.webosports.app.settings.backup": {
            "source": "General/BackupPage.qml",
            "icon": "images/icons/icon-backup.png",
            "title": "Backup (placeholder)"
        },
        "org.webosports.app.settings.certificate": {
            "source": "General/CertificatePage.qml",
            "icon": "images/icons/icon-certificate.png",
            "title": "Certificate Manager (placeholder)"
        },
        "org.webosports.app.settings.dateandtime": {
            "source": "General/DateAndTimePage.qml",
            "icon": "images/icons/icon-dateandtime.png",
            "title": "Date & Time (placeholder)"
        },
        "org.webosports.app.settings.devmodeswitcher": {
            "source": "General/DeveloperOptionsPage.qml",
            "icon": "images/icons/icon-devmodeswitcher.png",
            "title": "Developer Option (placeholder)"
        },
        "org.webosports.app.settings.deviceinfo": {
            "source": "General/DeviceInfoPage.qml",
            "icon": "images/icons/icon-deviceinfo.png",
            "title": "Device Info"
        },
        "org.webosports.app.settings.exhibitionpreferences": {
            "source": "General/DeveloperOptionsPage.qml",
            "icon": "images/icons/icon-exhibitionpreferences.png",
            "title": "Exhibition (placeholder)"
        },
        "org.webosports.app.settings.help": {
            "source": "General/HelpPage.qml",
            "icon": "images/icons/icon-help.png",
            "title": "Help (placeholder)"
        },
        "org.webosports.app.settings.languagepicker": {
            "source": "General/LanguagePickerPage.qml",
            "icon": "images/icons/icon-languagepicker.png",
            "title": "Regional Settings (placeholder)"
        },
        "org.webosports.app.settings.location": {
            "source": "General/LocationPage.qml",
            "icon": "images/icons/icon-location.png",
            "title": "Location Services (placeholder)"
        },
        "org.webosports.app.settings.screenlock": {
            "source": "General/ScreenLockPage.qml",
            "icon": "images/icons/icon-screenlock.png",
            "title": "Screen & Lock (placeholder)"
        },
        "org.webosports.app.settings.searchpreferences": {
            "source": "General/SearchPreferencesPage.qml",
            "icon": "images/icons/icon-searchpreferences.png",
            "title": "Just Type (placeholder)"
        },
        "org.webosports.app.settings.soundsandalerts": {
            "source": "General/SoundsAndAlertsPage.qml",
            "icon": "images/icons/icon-soundandalerts.png",
            "title": "Sounds & Ringtones (placeholder)"
        },
        "org.webosports.app.settings.updates": {
            "source": "General/UpdatesPage.qml",
            "icon": "images/icons/icon-updates.png",
            "title": "System Updates (placeholder)"
        },
        "org.webosports.app.settings.textassist": {
            "source": "General/TextAssistPage.qml",
            "icon": "images/icons/icon-textassist.png",
            "title": "Text Assist (placeholder)"
        }
    })

    property string categoryFile: categories[appId].source
    property string categoryIcon: categories[appId].icon
    property string categoryTitle: categories[appId].title

    property Loader _categoryLoader: categoryLoader  // useful for the tests

    Rectangle {
        z: -1
        anchors.fill: parent
        color: "#D8D8D8"
    }

    CategoryHeader {
        id: categoryHeader
        title: settingsCategoryAppWindow.categoryTitle
        icon: settingsCategoryAppWindow.categoryIcon

        height: Units.gu(10.0)
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
    }

    Loader {
        id: categoryLoader
        anchors.top: categoryHeader.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        source: categoryFile

        property alias actionHeaderComponent: categoryHeader.actionHeaderComponent
        onActionHeaderComponentChanged: console.log("actionHeaderComponent="+actionHeaderComponent);
    }
}
