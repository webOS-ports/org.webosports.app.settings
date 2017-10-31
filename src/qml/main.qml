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

    property QtObject application: QtObject {
        property string appId: "org.webosports.app.settings.example"
        property string launchParameters: "{}";
    }

    Connections {
        target: _categoryLoader
        onLoaded: categoryChooserDrawer.close();
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
            title: "WiFi"
            categorySection: "Connectivity"
            appId: "org.webosports.app.settings.wifi"
        }

        ListElement {
            title: "Bluetooth"
            categorySection: "Connectivity"
            appId: "org.webosports.app.settings.bluetooth"
        }

        ListElement {
            title: "Cellular"
            categorySection: "Connectivity"
            appId: "org.webosports.app.settings.phone"
        }

        ListElement {
            title: "About"
            categorySection: "General"
            appId: "org.webosports.app.settings.about"
        }

        ListElement {
            title: "Screen & Lock"
            categorySection: "General"
            appId: "org.webosports.app.settings.screenlock"
        }

        ListElement {
            title: "Date & Time"
            categorySection: "General"
            appId: "org.webosports.app.settings.datetime"
        }

        ListElement {
            title: "Developer Options"
            categorySection: "General"
            appId: "org.webosports.app.settings.developper"
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
                        application.appId = model.appId;
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
