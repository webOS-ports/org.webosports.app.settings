/*
 * (c) 2026 Herman van Hazendonk <github.com@herrie.org>
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

// Theme specific properties
import QtQuick.Controls.LuneOS 2.0
// Units & font sizes
import LunaNext.Common 0.1
// Connman
import Connman 0.2

import "../Common"

/*
 * Tethering, after webOS 3.0.5's Mobile Hotspot (com.palm.app.mobilehotspot).
 * The icon is that app's, unchanged.
 *
 * Nothing here was reachable before. NetworkSettingsPage says in its own
 * header that tethering "lives in the WiFi panel instead" on the four systems
 * it was written against, and left it out on that basis - but the Wi-Fi panel
 * here never grew it, so between the two pages there was no way to share a
 * connection at all.
 *
 * All three kinds are one connman idea: a technology with its Tethering
 * property set. There is no LS2 service in the way -
 * net.connman.Technology's Tethering, TetheringIdentifier and
 * TetheringPassphrase are plain upstream connman properties, not the Sailfish
 * fork's additions, and libconnman-qt binds all three - so this page talks to
 * connman directly the way WiFiPage does.
 *
 *  - Wi-Fi is the hotspot proper, and the only one of the three that takes a
 *    name and a password: connman answers TetheringIdentifier and
 *    TetheringPassphrase with "not supported" on any other technology.
 *  - USB is connman's "gadget" technology, which is the USB network gadget
 *    the device presents to a host it is plugged into.
 *  - Bluetooth is the PAN profile.
 *
 * Which of the three a device can do is connman's decision, not this page's:
 * its TetheringTechnologies setting defaults to exactly these three, and a
 * technology that is not present has no path, so the group for it does not
 * appear.
 *
 * The passphrase is held back until it is long enough. WPA2 has an eight
 * character minimum and connman rejects anything shorter outright, so sending
 * each keystroke would mean six failed calls before a good one.
 *
 * Not offered here, though LuneOS's connman has it: the tethering address
 * range and the AP channel, added by meta-webos-ports'
 * 0002-technology-add-TetheringIPAddress-and-TetheringChannel patch.
 * libconnman-qt does not bind those two, so reaching them would mean raw
 * D-Bus from a settings page. See docs/missing-services.md.
 */
BasePage {
    id: pageRoot

    NetworkManager {
        id: networkManager

        onTechnologiesChanged: pageRoot.refreshTechnologyPaths()
        onAvailabilityChanged: pageRoot.refreshTechnologyPaths()
    }

    property string wifiPath: ""
    property string gadgetPath: ""
    property string bluetoothPath: ""

    // How many devices are on the hotspot right now. connman keeps this per
    // manager rather than per technology, so it is the total across all
    // three.
    readonly property int clientCount: networkManager.tetheringClients
                                       ? networkManager.tetheringClients.length : 0

    Component.onCompleted: refreshTechnologyPaths();

    /*
     * All three by type rather than off the named properties.
     *
     * NetworkManager does have WifiTechnology and BluetoothTechnology, and
     * cardshell's AirplaneModeService reads them - but a QML type cannot
     * declare a property whose name starts with a capital, so the desktop
     * stub for this type physically cannot offer them and every such read is
     * undefined there. technologyPathForType exists on both, means the same
     * thing, and is the only spelling that is the same in both places. It is
     * also the only way to reach the USB gadget, which has no named property
     * at all.
     */
    function refreshTechnologyPaths() {
        pageRoot.wifiPath = networkManager.technologyPathForType("wifi");
        pageRoot.bluetoothPath = networkManager.technologyPathForType("bluetooth");
        pageRoot.gadgetPath = networkManager.technologyPathForType("gadget");
    }

    NetworkTechnology {
        id: wifiTechnology
        path: pageRoot.wifiPath
    }

    NetworkTechnology {
        id: gadgetTechnology
        path: pageRoot.gadgetPath
    }

    NetworkTechnology {
        id: bluetoothTechnology
        path: pageRoot.bluetoothPath
    }

    SettingsPageContent {
        ServiceUnavailableNotice {
            visible: pageRoot.wifiPath === "" && pageRoot.gadgetPath === "" &&
                     pageRoot.bluetoothPath === ""
            serviceName: "net.connman"
            description: "connman did not report any technology that can " +
                         "share this device's connection."
            onRetry: pageRoot.refreshTechnologyPaths()
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.wifiPath !== ""

            title: "Wi-Fi Hotspot"

            Column {
                width: parent.width

                LabelAndSwitch {
                    id: wifiTetheringSwitch
                    label: "Share over Wi-Fi"

                    checked: wifiTechnology.tethering
                    Connections {
                        target: wifiTechnology
                        function onTetheringChanged() {
                            wifiTetheringSwitch.checked = wifiTechnology.tethering;
                        }
                    }
                    onToggled: wifiTechnology.tethering = checked
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndTextField {
                    id: ssidField
                    width: parent.width
                    label: "Name"
                    placeholderText: "LuneOS"

                    text: wifiTechnology.tetheringId
                    Connections {
                        target: wifiTechnology
                        function onTetheringIdChanged() {
                            if (!ssidField.activeFocus)
                                ssidField.text = wifiTechnology.tetheringId;
                        }
                    }
                    onEdited: (text) => { if (text !== "") wifiTechnology.tetheringId = text; }
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndTextField {
                    id: passphraseField
                    width: parent.width
                    label: "Password"
                    placeholderText: "At least 8 characters"
                    // Held back until it is long enough - see the file header.
                    acceptable: text.length === 0 || text.length >= 8

                    text: wifiTechnology.tetheringPassphrase
                    Connections {
                        target: wifiTechnology
                        function onTetheringPassphraseChanged() {
                            if (!passphraseField.activeFocus)
                                passphraseField.text = wifiTechnology.tetheringPassphrase;
                        }
                    }
                    onEdited: (text) => {
                        if (text.length >= 8)
                            wifiTechnology.tetheringPassphrase = text;
                    }
                }
            }
        }

        ExplanationText {
            visible: pageRoot.wifiPath !== ""
            text: "The Wi-Fi radio cannot be a hotspot and be joined to a " +
                  "network at the same time, so turning this on drops the " +
                  "Wi-Fi connection. Anything the device does over the " +
                  "internet from then on goes over mobile data."
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.gadgetPath !== ""

            title: "USB"

            Column {
                width: parent.width

                LabelAndSwitch {
                    id: gadgetTetheringSwitch
                    label: "Share over USB"

                    checked: gadgetTechnology.tethering
                    Connections {
                        target: gadgetTechnology
                        function onTetheringChanged() {
                            gadgetTetheringSwitch.checked = gadgetTechnology.tethering;
                        }
                    }
                    onToggled: gadgetTechnology.tethering = checked
                }
            }
        }

        ExplanationText {
            visible: pageRoot.gadgetPath !== ""
            text: "The computer the device is plugged into sees a network " +
                  "adapter and reaches the internet through it."
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.bluetoothPath !== ""

            title: "Bluetooth"

            Column {
                width: parent.width

                LabelAndSwitch {
                    id: bluetoothTetheringSwitch
                    label: "Share over Bluetooth"

                    checked: bluetoothTechnology.tethering
                    Connections {
                        target: bluetoothTechnology
                        function onTetheringChanged() {
                            bluetoothTetheringSwitch.checked = bluetoothTechnology.tethering;
                        }
                    }
                    onToggled: bluetoothTechnology.tethering = checked
                }
            }
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.clientCount > 0

            title: "Connected"

            Column {
                width: parent.width

                LabelAndValue {
                    width: parent.width
                    label: "Devices"
                    value: pageRoot.clientCount === 1 ? "1 device"
                                                      : pageRoot.clientCount + " devices"
                }
            }
        }
    }
}
