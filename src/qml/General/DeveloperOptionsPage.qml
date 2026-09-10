/*
 * (c) 2017 Christophe Chapuis <chris.chapuis@gmail.com>
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
 * Developer Mode, after the webOS 3.0.5 app of the same name
 * (com.palm.app.devmodeswitcher).
 *
 * Until now this page was still the ExamplePage template it was copied from
 * in 2017 - it shipped as a launcher entry offering "Hourly Coffee" and
 * "Search in Wikipedia" against no service at all - while
 * org.webosports.service.devmode, which is what actually turns developer mode
 * on, had no UI anywhere.
 *
 * That service has two switches and this page is those two switches:
 *  - getStatus returns "status" and "usbDebugging", each "enabled" or
 *    "disabled".
 *  - setStatus takes either or both. "status" writes or removes
 *    /var/luna/dev-mode-enabled; "usbDebugging" writes or removes
 *    /var/usb-debugging-enabled and starts or stops android-tools-adbd with
 *    it. Turning developer mode off stops adbd too, which is why the switch
 *    below follows it down.
 *
 * The reply is not trusted for the result. setStatus builds its returnValue
 * from a "success" flag that the usbDebugging path only sets inside an
 * asynchronous fs callback, after the reply has already been composed - so a
 * change that worked can still answer false. Every change is followed by a
 * fresh getStatus, and that is what the switches are drawn from.
 *
 * The legacy app also had a "Change Password" row. That was novacom's
 * password and there is no novacom here: LuneOS reaches a device over adb
 * where the Android tools are installed, and over ssh everywhere.
 */
BasePage {
    id: pageRoot

    property bool serviceAvailable: false
    property bool devModeEnabled: false
    property bool usbDebuggingEnabled: false

    Component.onCompleted: retrieveProperties();

    SettingsPageContent {
        ServiceUnavailableNotice {
            visible: !pageRoot.serviceAvailable
            serviceName: "org.webosports.service.devmode"
            description: "Developer mode is turned on and off by this service, " +
                         "so nothing here can be changed until it answers."
            onRetry: pageRoot.retrieveProperties()
        }

        GroupBox {
            width: parent.width
            enabled: pageRoot.serviceAvailable

            Column {
                width: parent.width

                LabelAndSwitch {
                    id: devModeSwitch
                    label: "Developer Mode"

                    checked: pageRoot.devModeEnabled
                    Connections {
                        target: pageRoot
                        function onDevModeEnabledChanged() {
                            devModeSwitch.checked = pageRoot.devModeEnabled;
                        }
                    }
                    onToggled: pageRoot.setDevMode(checked)
                }
            }
        }

        ExplanationText {
            text: "Developer mode marks the device as one that is being " +
                  "worked on. It is what the developer tools look for before " +
                  "they will do anything to it."
        }

        GroupBox {
            width: parent.width
            enabled: pageRoot.serviceAvailable

            title: "Debugging"

            Column {
                width: parent.width

                LabelAndSwitch {
                    id: usbDebuggingSwitch
                    label: "USB Debugging"
                    // adbd is started by the same service and stopped again
                    // when developer mode goes off, so there is nothing to
                    // turn on while that is off.
                    enabled: pageRoot.devModeEnabled

                    checked: pageRoot.usbDebuggingEnabled
                    Connections {
                        target: pageRoot
                        function onUsbDebuggingEnabledChanged() {
                            usbDebuggingSwitch.checked = pageRoot.usbDebuggingEnabled;
                        }
                    }
                    onToggled: pageRoot.setUsbDebugging(checked)
                }
            }
        }

        ExplanationText {
            text: pageRoot.devModeEnabled
                  ? "USB Debugging runs the Android adb daemon, so it only " +
                    "does something on a device that has the Android tools - " +
                    "a Halium port. ssh is listening on every build and does " +
                    "not need this."
                  : "Turn Developer Mode on first. USB Debugging is stopped " +
                    "with it."
        }
    }

    /*
     * Bindings with the devmode service
     */
    function retrieveProperties() {
        luna.call("luna://org.webosports.service.devmode/getStatus", "{}",
                  _handleGetStatus, _handleServiceUnavailable);
    }

    function _handleGetStatus(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue) {
            pageRoot.serviceAvailable = false;
            return;
        }

        pageRoot.devModeEnabled = response.status === "enabled";
        pageRoot.usbDebuggingEnabled = response.usbDebugging === "enabled";
        pageRoot.serviceAvailable = true;
    }

    function _handleServiceUnavailable(message) {
        console.warn("Developer mode service did not answer: " + message);
        pageRoot.serviceAvailable = false;
    }

    function setDevMode(on) {
        // Turning developer mode off stops adbd in the service, so show that
        // here straight away rather than leaving a switch on for the second
        // it takes getStatus to come back and say otherwise.
        pageRoot.devModeEnabled = on;
        if (!on)
            pageRoot.usbDebuggingEnabled = false;

        _setStatus({"status": on ? "enabled" : "disabled"});
    }

    function setUsbDebugging(on) {
        pageRoot.usbDebuggingEnabled = on;
        _setStatus({"usbDebugging": on ? "enabled" : "disabled"});
    }

    function _setStatus(params) {
        luna.call("luna://org.webosports.service.devmode/setStatus",
                  JSON.stringify(params),
                  _handleSetStatus, _handleSetStatusError);
    }

    function _handleSetStatus(message) {
        // See the file header: returnValue is not reliable for the
        // usbDebugging path, so ask what the state actually is.
        retrieveProperties();
    }

    function _handleSetStatusError(message) {
        console.warn("Cannot change developer mode: " + message);
        retrieveProperties();
    }
}
