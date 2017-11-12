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
import QtQuick.Layouts 1.3

// Theme specific properties
import QtQuick.Controls.LuneOS 2.0

import "../Common"

// Units & font sizes
import LunaNext.Common 0.1
// Connman
import Connman 0.2

BasePage {
    id: wifiPageId

    TechnologyModel {
        id: wifiModel
        name: "wifi"
    }

    Component.onCompleted: {
        retrieveProperties();
    }

    pageActionHeaderComponent: Component {
        Switch {
            id: wifiPowerSwitch
            LuneOSSwitch.labelOn: "On"
            LuneOSSwitch.labelOff: "Off"

            Connections {
                target: wifiModel
                onPoweredChanged: wifiPowerSwitch.checked=wifiModel.powered;
            }
            checked: wifiModel.powered
            onCheckedChanged: wifiModel.powered=checked;
        }
    }

    /* GroupBoxes look good! */
    GroupBox {
        anchors.fill: parent

        title: "Choose a network"
        ColumnLayout {
            anchors.fill: parent

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                model: wifiModel

                delegate: Item {
                    property NetworkService delegateService: modelData

                    width: parent.width
                    height: Units.gu(6)

                    RowLayout {
                        anchors.fill: parent

                        Label {
                            height: parent.height
                            text: delegateService.name
                            Layout.fillWidth: true
                            font.pixelSize: FontUtils.sizeToPixels("medium")
                        }
                        Label {
                            id: networkStatus
                            text: "connecting..."
                            visible: delegateService.connecting
                            color: "darkblue"
                            font.pixelSize: FontUtils.sizeToPixels("small")
                        }
                        Image {
                            source: "../images/wifi/checkmark.png"
                            visible: delegateService.connected

                            fillMode: Image.PreserveAspectFit
                            verticalAlignment: Image.AlignVCenter
                            horizontalAlignment: Image.AlignHCenter
                            Layout.preferredHeight: Units.gu(3.2)
                            Layout.preferredWidth: Units.gu(3.2)
                        }
                        Image {
                            source: "../images/secure-icon.png"
                            visible: delegateService.securityType !== NetworkService.SecurityNone

                            fillMode: Image.PreserveAspectFit
                            verticalAlignment: Image.AlignVCenter
                            horizontalAlignment: Image.AlignHCenter
                            Layout.preferredHeight: Units.gu(3.2)
                            Layout.preferredWidth: Units.gu(3.2)
                        }
                        Image {
                            source: "../images/wifi/signal-icon-" + Math.floor(delegateService.strength/25) + ".png"

                            fillMode: Image.PreserveAspectFit
                            verticalAlignment: Image.AlignVCenter
                            horizontalAlignment: Image.AlignHCenter
                            Layout.preferredHeight: Units.gu(3.2)
                            Layout.preferredWidth: Units.gu(3.2)
                        }
                    }
                    Rectangle {
                        // separator
                        color: "black"
                        height: 1
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        visible: index !== wifiModel.count-1
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if(delegateService.connected) {
                                delegateService.requestDisconnect();
                            }
                            else {
                                // if this service needs a password and we don't have it yet,
                                // connman will ask the user through the UserAgent down below
                                delegateService.requestConnect();
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                height: Units.gu(3.2)
                Image {
                    source: "../images/icon-new.png"

                    Layout.preferredHeight: parent.height
                    Layout.preferredWidth: height

                    fillMode: Image.PreserveAspectCrop
                    verticalAlignment: Image.AlignTop
                }
                Label {
                    height: parent.height
                    Layout.fillWidth: true
                    text: "Join Network"
                }
            }
        }
    }

    footer: Label {
        font.italic: true
        text: "Your device automatically connects to known networks."
    }

    UserAgent {
        id: connmanUserAgent
        onUserInputRequested: //(string servicePath, variant /*QVariantMap*/ fields);
        {
            // Find out the name of this servicePath
            var serviceName = "";
            for(var i=0; i<wifiModel.count; ++i) {
                var networkService = wifiModel.get(i);
                if(networkService.path === servicePath) {
                    serviceName = networkService.name;
                    break;
                }
            }

            popupLoader.setSource(Qt.resolvedUrl("WiFiProvidePassphrasePopup.qml"),
                                  {"agent": connmanUserAgent, "serviceName": serviceName, "requestedFields": fields});
        }
    }

    Loader {
        id: popupLoader
        anchors.fill: parent

        onItemChanged: {
            if(item && item.onClosed) {
                item.onClosed.connect(function() {
                    // ensure the component is unlaaded
                    if(!item.visible) popupLoader.source = "";
                });
            }
        }
    }

    function retrieveProperties() {
        // nothing special to retrieve here
    }
}
