/*
 * (c) 2013 Simon Busch <morphis@gravedo.de>
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

GenericCategoryWindow {
    id: testingApp

    width: 400
    height: 800
    visible: true

    appId: "org.webosports.app.settings.example"
    launchParams: "{}"

    Connections {
        target: _categoryLoader
        function onLoaded() {
            categoryChooserDrawer.close();
        }
    }

    ListModel {
        id: settingsModel

        /* NOTE: Make sure you add new items below correctly ordered! Otherwise the
           sectioning will not work propably as ListView expects and ordered list by
           section */

        ListElement {
            title: "Example"
            categorySection: "Testing"
            appId: "org.webosports.app.settings.example"
        }

        ListElement {
            title: "Bluetooth"
            categorySection: "Connectivity"
            appId: "org.webosports.app.settings.bluetooth"
        }

        ListElement {
            title: "Network Settings"
            categorySection: "Connectivity"
            appId: "org.webosports.app.settings.networksettings"
        }

        ListElement {
            title: "VPN"
            categorySection: "Connectivity"
            appId: "org.webosports.app.settings.vpn"
        }

        ListElement {
            title: "WiFi"
            categorySection: "Connectivity"
            appId: "org.webosports.app.settings.wifi"
        }

        ListElement {
            title: "Backup"
            categorySection: "General"
            appId: "org.webosports.app.settings.backup"
        }

        ListElement {
            title: "Certificate Manager"
            categorySection: "General"
            appId: "org.webosports.app.settings.certificate"
        }

        ListElement {
            title: "Date & Time"
            categorySection: "General"
            appId: "org.webosports.app.settings.dateandtime"
        }

        ListElement {
            title: "Developer Options"
            categorySection: "General"
            appId: "org.webosports.app.settings.devmodeswitcher"
        }

        ListElement {
            title: "Device Info"
            categorySection: "General"
            appId: "org.webosports.app.settings.deviceinfo"
        }

        ListElement {
            title: "Exhibition"
            categorySection: "General"
            appId: "org.webosports.app.settings.exhibitionpreferences"
        }

        ListElement {
            title: "Help"
            categorySection: "General"
            appId: "org.webosports.app.settings.help"
        }

        ListElement {
            title: "Just Type"
            categorySection: "General"
            appId: "org.webosports.app.settings.searchpreferences"
        }

        ListElement {
            title: "Location Services"
            categorySection: "General"
            appId: "org.webosports.app.settings.location"
        }

        ListElement {
            title: "Regional Settings"
            categorySection: "General"
            appId: "org.webosports.app.settings.languagepicker"
        }

        ListElement {
            title: "Screen & Lock"
            categorySection: "General"
            appId: "org.webosports.app.settings.screenlock"
        }

        ListElement {
            title: "Sounds & Ringtones"
            categorySection: "General"
            appId: "org.webosports.app.settings.soundsandalerts"
        }

        ListElement {
            title: "System Updates"
            categorySection: "General"
            appId: "org.webosports.app.settings.updates"
        }

        ListElement {
            title: "Text Assist"
            categorySection: "General"
            appId: "org.webosports.app.settings.textassist"
        }
    }

    Drawer {
        id: categoryChooserDrawer
        edge: Qt.LeftEdge
        width: 300
        height: testingApp.height

        ListView {
            id: settingsList

            anchors.fill: parent

            model: settingsModel
            delegate: Rectangle {
                id: listItem
                width: settingsList.width
                height: 44
                color: "#333333"

                Text {
                    text: title
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    font.pixelSize: 18
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "black"
                    anchors.bottom: parent.bottom
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        console.log("Switching to app " + model.appId);
                        testingApp.appId = model.appId;
                    }
                }
            }

            section.property: "categorySection"
            section.criteria: ViewSection.FullString
            section.delegate: Rectangle {
                width: settingsList.width
                height: 30
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#777" }
                    GradientStop { position: 1.0; color: "#555" }
                }
                Text {
                    text: section
                    font.bold: true
                    font.pixelSize: 14
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    color: "white"
                    verticalAlignment: Text.AlignVCenter
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    Component.onCompleted: categoryChooserDrawer.open()
}
