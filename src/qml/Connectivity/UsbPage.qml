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

import "../Common"

/*
 * USB, roughly where webOS 3.0.5 put com.palm.app.usbpassthrough - though
 * that app was a scene the system threw up when a cable was plugged in
 * rather than a settings page, and there was no settings page for any of
 * this. SFOS, UBports and FuriOS all have one.
 *
 * What LuneOS can offer over a cable is narrower than what those three
 * offer, and the page says so rather than drawing switches for the rest:
 *
 *  - Media transfer. On Palm hardware "mass storage mode" exported a real
 *    partition as a block device. LuneOS keeps the name and the whole LS2
 *    interface - com.palm.storage's diskmode category, unchanged since Open
 *    webOS - but the nyx module behind it is msm_mtp, which starts umtprd
 *    and presents the device over MTP instead. Same call, different protocol
 *    on the wire, and MTP is what a modern host expects anyway.
 *
 *  - Charging. That is simply neither of the other two being on.
 *
 * It is a button and not a switch because there is no way back through this
 * interface. diskmode has enterMSM and no matching leave: mass storage mode
 * ends when the host ejects the volume or the cable comes out, which is what
 * drives storaged's cable and eject handlers. Offering an off switch that
 * had nothing to call would be worse than saying how it ends.
 *
 * enterMSM also does nothing at all unless a host is already connected - it
 * checks NYX_MASS_STORAGE_MODE_HOST_CONNECTED first and returns quietly - so
 * the button is disabled until one is.
 *
 * The two things that do go over the same cable and are not here have panels
 * of their own, and this one links to both: adb is Developer Mode's USB
 * Debugging switch, and USB tethering is connman's gadget technology, on
 * Tethering.
 *
 * Note storaged is an on-demand service that exits about ten seconds after
 * it stops being asked anything. Calling it starts it again, so a stale
 * reading is not possible, but neither is a long-lived subscription: the
 * page follows the MSMAvail and MSMStatus signals it sends while it is up
 * and re-reads on each.
 */
BasePage {
    id: pageRoot

    property bool storageServiceAvailable: false
    property bool hostConnected: false
    property bool inMassStorageMode: false

    Component.onCompleted: retrieveProperties();

    SettingsPageContent {
        ServiceUnavailableNotice {
            visible: !pageRoot.storageServiceAvailable
            serviceName: "com.palm.storage"
            description: "The storage daemon did not answer, so this device " +
                         "cannot be offered to a computer over the cable."
            onRetry: pageRoot.retrieveProperties()
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.storageServiceAvailable

            title: "Connection"

            Column {
                width: parent.width

                LabelAndValue {
                    width: parent.width
                    label: "Cable"
                    value: pageRoot.hostConnected ? "Connected to a computer"
                                                  : "Not connected"
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndValue {
                    width: parent.width
                    label: "Mode"
                    value: pageRoot.inMassStorageMode ? "Media transfer"
                                                      : (pageRoot.hostConnected ? "Charging"
                                                                                : "None")
                }
            }
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.storageServiceAvailable

            Column {
                width: parent.width

                Button {
                    text: "Connect as media device"
                    enabled: pageRoot.hostConnected && !pageRoot.inMassStorageMode
                    onClicked: pageRoot.enterMediaTransfer()
                }
            }
        }

        ExplanationText {
            visible: pageRoot.storageServiceAvailable
            text: {
                if (!pageRoot.hostConnected)
                    return "Plug the device into a computer first.";
                if (pageRoot.inMassStorageMode)
                    return "The computer can see the device's files. It stops " +
                           "when the computer ejects it or the cable comes out.";
                return "The computer will see the device's files over MTP. It " +
                       "stops when the computer ejects it or the cable comes out.";
            }
        }

        GroupBox {
            width: parent.width

            title: "Also over the cable"

            Column {
                width: parent.width
                spacing: Units.gu(1)

                Button {
                    text: "USB Debugging"
                    LuneOSButton.mainColor: LuneOSButton.secondaryColor
                    onClicked: pageRoot.openDeveloperSettings()
                }

                Button {
                    text: "USB Tethering"
                    LuneOSButton.mainColor: LuneOSButton.secondaryColor
                    onClicked: pageRoot.openTetheringSettings()
                }
            }
        }

        ExplanationText {
            text: "adb is on the Developer Mode panel. Sharing this device's " +
                  "internet connection with the computer is on Tethering."
        }
    }

    /*
     * Bindings with storaged
     */
    function retrieveProperties() {
        readHostConnected();
        readMassStorageMode();

        // storaged publishes both of these whenever they move. It is not
        // running all the time, so a signal only arrives while it is up -
        // which is exactly when there is something to report.
        luna.subscribe("luna://com.palm.bus/signal/addmatch",
                       JSON.stringify({"category": "/storaged",
                                       "method": "MSMAvail"}),
                       _handleStorageSignal, _handleSignalError);

        luna.subscribe("luna://com.palm.bus/signal/addmatch",
                       JSON.stringify({"category": "/storaged",
                                       "method": "MSMStatus"}),
                       _handleStorageSignal, _handleSignalError);
    }

    function readHostConnected() {
        luna.call("luna://com.palm.storage/diskmode/hostIsConnected", "{}",
                  _handleHostConnected, _handleStorageUnavailable);
    }

    function readMassStorageMode() {
        luna.call("luna://com.palm.storage/diskmode/queryMSMStatus", "{}",
                  _handleMassStorageMode, _handleStorageUnavailable);
    }

    /*
     * diskmode answers with "result", not the "returnValue" every other
     * service on the device uses. It has done since Open webOS; do not
     * "correct" it here.
     */
    function _handleHostConnected(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.result)
            return;

        pageRoot.hostConnected = response.hostIsConnected === true;
        pageRoot.storageServiceAvailable = true;
    }

    function _handleMassStorageMode(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.result)
            return;

        pageRoot.inMassStorageMode = response.inMSM === true;
        pageRoot.storageServiceAvailable = true;
    }

    function _handleStorageSignal(message) {
        // Both signals carry only the one fact that changed; re-read both so
        // the two rows can never disagree.
        readHostConnected();
        readMassStorageMode();
    }

    function _handleSignalError(message) {
        console.warn("Cannot follow USB changes: " + message);
    }

    function _handleStorageUnavailable(message) {
        console.warn("Storage daemon did not answer: " + message);
        pageRoot.storageServiceAvailable = false;
    }

    function enterMediaTransfer() {
        // "user-confirmed" is storaged's way of being told this is a
        // deliberate choice and not a cable event; the button is the
        // confirmation.
        luna.call("luna://com.palm.storage/diskmode/enterMSM",
                  JSON.stringify({"user-confirmed": true}),
                  _handleEnterMassStorageMode, _handleStorageUnavailable);
    }

    function _handleEnterMassStorageMode(message) {
        // The reply says the request was taken, not that the mode is on -
        // that arrives as an MSMStatus signal once umtprd is up.
        readMassStorageMode();
    }

    // Each settings category is its own launchable application on the device.
    function openDeveloperSettings() {
        luna.call("luna://com.webos.service.applicationManager/launch",
                  JSON.stringify({"id": "org.webosports.app.settings.devmodeswitcher"}),
                  _handleSetSuccess, _handleSetError);
    }

    function openTetheringSettings() {
        luna.call("luna://com.webos.service.applicationManager/launch",
                  JSON.stringify({"id": "org.webosports.app.settings.tethering"}),
                  _handleSetSuccess, _handleSetError);
    }
}
