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

// 2.12 for TapHandler, which the network rows need - see the delegate
import QtQuick 2.12
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
                function onPoweredChanged () {
                    wifiPowerSwitch.checked=wifiModel.powered;
                }
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

                delegate: ItemDelegate {
                    property NetworkService delegateService: modelData

                    width: parent.width
                    height: Units.gu(6)

                    RowLayout {
                        anchors.fill: parent

                        Label {
                            height: parent.height
                            text: delegateService.name
                            font.bold: delegateService.connected
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
                            Layout.preferredWidth: Units.gu(1.5)
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
                    // Show a separator between items
                    HorizontalSeparator {
                        anchors.bottom: parent.bottom
                        width: parent.width
                    }

                    /*
                     * A TapHandler and not a MouseArea, because this row
                     * lives in a ListView.
                     *
                     * MouseArea.pressAndHold does not survive being inside a
                     * Flickable: the list filters its children's mouse
                     * events, and the first move takes the grab away and
                     * cancels the hold timer with it. Measured with a
                     * synthesised press: perfectly still, the hold fires;
                     * four pixels of movement during it, and it never does -
                     * and four pixels is less than the ten pixel drag
                     * threshold, so the list does not even scroll. A finger
                     * planted on glass reports no movement, which is why
                     * this worked on a device and not with a mouse.
                     *
                     * A pointer handler is built to share a press with a
                     * Flickable rather than lose it, so the hold survives
                     * the drift and a real drag still scrolls the list.
                     */
                    TapHandler {
                        id: networkTap

                        // Set once the hold has fired, so the release that
                        // follows does not also toggle the connection - what
                        // MouseArea used to do for free by suppressing
                        // clicked() after pressAndHold().
                        property bool heldOpen: false

                        longPressThreshold: 0.8

                        onPressedChanged: if (pressed) networkTap.heldOpen = false

                        onLongPressed: {
                            networkTap.heldOpen = true;
                            networkInfoPopup.service = delegateService;
                            networkInfoPopup.open();
                        }

                        onTapped: {
                            if (networkTap.heldOpen)
                                return;

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

                ScrollIndicator.vertical: ScrollIndicator { }
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
        width: parent.width
        wrapMode: Label.WordWrap
        font.italic: true
        // Press-and-hold is worth saying out loud: there is nothing on the
        // row itself to suggest a network has a details page behind it.
        text: "Your device automatically connects to known networks. "
              + "Touch and hold a network to see its details."
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
        // connman can cancel a pending request out from under the popup -
        // the network went out of range, or another client answered it
        // first. Left unhandled, the popup keeps showing a prompt the agent
        // has already discarded; submitting it then would silently do
        // nothing (UserAgent::sendUserReply() just warns and returns when
        // there is no request left to answer), which is exactly what
        // "entered a password and nothing happened" looks like from here.
        onUserInputCanceled: popupLoader.source = ""
    }

    WiFiNetworkInfoPopup {
        id: networkInfoPopup
        // For the dBm reading and the channel width, which connman has no
        // way to report - see the popup for why.
        luna: wifiPageId.luna
        // Nothing to keep once it is off screen, and holding the service
        // would keep this pinned to a network the list may have dropped.
        onClosed: service = null
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
