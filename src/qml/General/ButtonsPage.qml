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

import QtQuick.Controls.LuneOS 2.0

import LunaNext.Common 0.1

import "../Common"
import LuneOS.Forms 1.0

/*
 * What the device's extra buttons do: an assistant button, a camera key.
 *
 * Which buttons there are is the device's to say, not this page's. The shell's
 * HardwareKeys connector reads /etc/luneos/hardware-keys.json, which
 * luneos-device-config writes from the adaptation's deviceinfo_key_actions; a
 * key given a "label" there is one the user may set up, and those are the keys
 * listed here. Every other key keeps the meaning the device gave it. On the
 * FuriLabs FLX1s, for instance, KEY_CAMERA is the camera privacy switch and is
 * deliberately not offered.
 *
 * The choices go to the shell's "hardwareKeyActions" tweak, held by
 * org.webosports.service.tweaks.prefs as JSON:
 *
 *     {"Key_Launch2": {"press": "torch.toggle", "hold": "app.camera"}}
 *
 * The shell subscribes to it, so a choice takes effect as soon as it is made.
 * The action names are the shell's; it ignores any it does not know, and any
 * choice for a key the device does not offer.
 */
BasePage {
    id: pageRoot

    //! The device's key file. A property so the tests can give it another.
    property string deviceFile: "/etc/luneos/hardware-keys.json"

    //! The keys the device offers, [{ name, label, press, hold }], with the
    //! device's own actions for them.
    property var keys: []
    //! What the user chose, key name -> { press, hold }.
    property var choices: ({})
    property bool tweaksAvailable: false
    //! The applications a key can open, from the application manager.
    property var apps: []

    readonly property string tweakOwner: "luna-next-cardshell"
    readonly property string tweakKey: "hardwareKeyActions"

    //! The shell's actions that make sense on a spare button, in the order
    //! they are offered. Call keys and the shell's own Back are left out: they
    //! only mean something on the key that is labelled for them.
    readonly property var actionChoices: [
        { "key": "none", "label": "Nothing" },
        { "key": "app.camera", "label": "Open Camera" },
        { "key": "torch.toggle", "label": "Torch on or off" },
        { "key": "shell.launcher", "label": "Show the launcher" },
        { "key": "display.sleep", "label": "Turn the screen off" },
        { "key": "audio.mute", "label": "Mute" },
        { "key": "media.headset", "label": "Play or pause" },
        { "key": "media.next", "label": "Next track" },
        { "key": "media.previous", "label": "Previous track" }
    ]

    //! Every choice the picker offers: the actions above, then each application.
    readonly property var pickerEntries: {
        var list = actionChoices.slice();
        var sorted = apps.slice().sort(function (a, b) {
            return _appTitle(a).localeCompare(_appTitle(b));
        });
        for (var i = 0; i < sorted.length; i++)
            list.push({ "key": "app.launch:" + sorted[i].id,
                        "label": "Open " + _appTitle(sorted[i]) });
        return list;
    }

    Component.onCompleted: retrieveProperties();

    SettingsPageContent {
        ServiceUnavailableNotice {
            visible: !pageRoot.tweaksAvailable && pageRoot.keys.length > 0
            serviceName: "org.webosports.service.tweaks.prefs"
            description: "What the buttons do is kept by the tweaks service."
            onRetry: pageRoot.retrieveTweaks()
        }

        ExplanationText {
            objectName: "noButtons"
            visible: pageRoot.keys.length === 0
            text: "This device has no buttons that can be set up here. " +
                  "Power and volume always do what they say."
        }

        Repeater {
            model: pageRoot.tweaksAvailable ? pageRoot.keys : []

            delegate: GroupBox {
                id: keyBox
                objectName: "key_" + modelData.name
                width: parent.width
                title: modelData.label

                Column {
                    width: parent.width

                    LabelAndPicker {
                        objectName: "press"
                        width: parent.width
                        label: "Press"
                        value: pageRoot.actionLabel(pageRoot.actionFor(modelData.name, "press"))
                        onClicked: actionPicker.openFor(modelData.name, "press",
                                                        modelData.label + ": press")
                    }

                    HorizontalSeparator {
                        width: parent.width
                    }

                    LabelAndPicker {
                        objectName: "hold"
                        width: parent.width
                        label: "Press and hold"
                        value: pageRoot.actionLabel(pageRoot.actionFor(modelData.name, "hold"))
                        onClicked: actionPicker.openFor(modelData.name, "hold",
                                                        modelData.label + ": press and hold")
                    }
                }
            }
        }

        ExplanationText {
            visible: pageRoot.tweaksAvailable && pageRoot.keys.length > 0
            text: "With something set for press and hold, a short press waits " +
                  "until the button is let go, to tell the two apart."
        }
    }

    ListPickerPopup {
        id: actionPicker
        objectName: "actionPicker"

        property string keyName: ""
        property string slot: "press"

        entries: pageRoot.pickerEntries
        currentKey: keyName !== "" ? pageRoot.actionFor(keyName, slot) : ""

        function openFor(name, which, rowTitle) {
            keyName = name;
            slot = which;
            title = rowTitle;
            open();
        }

        onPicked: (key, entry) => pageRoot.setChoice(actionPicker.keyName, actionPicker.slot, key)
    }

    /*
     * What the keys do
     */

    //! The labelled keys of the device's key file, in the file's order.
    function parseDeviceKeys(text) {
        var result = [];
        if (!text)
            return result;
        var parsed;
        try {
            parsed = JSON.parse(text);
        } catch (e) {
            console.warn("ButtonsPage: cannot parse " + pageRoot.deviceFile + ": " + e);
            return result;
        }
        if (!parsed || typeof parsed !== "object")
            return result;
        for (var name in parsed) {
            var entry = parsed[name];
            if (!entry || typeof entry !== "object" ||
                    typeof entry.label !== "string" || entry.label === "")
                continue;
            result.push({
                "name": name,
                "label": entry.label,
                "press": _validOr(entry.press, "none"),
                "hold": _validOr(entry.hold, "none")
            });
        }
        return result;
    }

    //! The tweak's JSON as an object; anything unreadable is no choices at all.
    function parseChoices(text) {
        if (typeof text !== "string" || text === "")
            return {};
        try {
            var parsed = JSON.parse(text);
            return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
        } catch (e) {
            console.warn("ButtonsPage: cannot parse the " + tweakKey + " tweak: " + e);
            return {};
        }
    }

    //! The action in force for one slot of a key: the user's, else the device's.
    function actionFor(name, slot) {
        var choice = pageRoot.choices[name];
        if (choice && typeof choice === "object" && isKnownAction(choice[slot]))
            return choice[slot];
        for (var i = 0; i < pageRoot.keys.length; i++) {
            if (pageRoot.keys[i].name === name)
                return pageRoot.keys[i][slot];
        }
        return "none";
    }

    //! Mirrors the shell's HardwareKeys.isKnownAction, for the actions this
    //! page offers: a value the shell would ignore is not shown as in force.
    function isKnownAction(action) {
        if (typeof action !== "string")
            return false;
        for (var i = 0; i < actionChoices.length; i++) {
            if (actionChoices[i].key === action)
                return true;
        }
        return /^app\.launch:[A-Za-z0-9][A-Za-z0-9._-]*$/.test(action);
    }

    //! What an action is called on the page.
    function actionLabel(action) {
        for (var i = 0; i < actionChoices.length; i++) {
            if (actionChoices[i].key === action)
                return actionChoices[i].label;
        }
        if (typeof action === "string" && action.indexOf("app.launch:") === 0) {
            var id = action.substring("app.launch:".length);
            for (var j = 0; j < apps.length; j++) {
                if (apps[j].id === id)
                    return "Open " + _appTitle(apps[j]);
            }
            return "Open " + id;
        }
        return "Nothing";
    }

    function setChoice(name, slot, action) {
        if (!isKnownAction(action))
            return;
        // A fresh object, so that the bindings reading choices see the change.
        var next = JSON.parse(JSON.stringify(pageRoot.choices));
        if (!next[name] || typeof next[name] !== "object")
            next[name] = {};
        next[name][slot] = action;
        pageRoot.choices = next;
        setTweak(JSON.stringify(next));
    }

    function _validOr(action, fallback) {
        return isKnownAction(action) ? action : fallback;
    }

    function _appTitle(app) {
        return app.title ? app.title : app.id;
    }

    /*
     * Bindings with LuneOS
     */
    function retrieveProperties() {
        pageRoot.keys = parseDeviceKeys(_readFile(pageRoot.deviceFile));
        retrieveTweaks();
        luna.subscribe("luna://com.webos.service.applicationManager/listApps",
                       JSON.stringify({"subscribe": true}),
                       _handleListApps, _handleGetError);
    }

    // file:// reads need QML_XHR_ALLOW_FILE_READ, which SAM sets for QML
    // applications. An absent file is a device with no such keys.
    function _readFile(path) {
        var xhr = new XMLHttpRequest();
        try {
            xhr.open("GET", "file://" + path, false);
            xhr.send();
        } catch (e) {
            console.warn("ButtonsPage: cannot read " + path + ": " + e);
            return "";
        }
        return xhr.responseText || "";
    }

    function retrieveTweaks() {
        luna.call("luna://org.webosports.service.tweaks.prefs/get",
                  JSON.stringify({"owner": pageRoot.tweakOwner, "keys": [pageRoot.tweakKey]}),
                  _handleGetTweaks, _handleTweaksUnavailable);
    }

    function _handleGetTweaks(message) {
        if (!message || !message.payload)
            return;
        var response = JSON.parse(message.payload);
        if (response.returnValue === false) {
            pageRoot.tweaksAvailable = false;
            return;
        }
        pageRoot.choices = parseChoices(response[pageRoot.tweakKey]);
        pageRoot.tweaksAvailable = true;
    }

    function _handleTweaksUnavailable(message) {
        console.warn("Tweaks service did not answer: " + message);
        pageRoot.tweaksAvailable = false;
    }

    function _handleListApps(message) {
        if (!message || !message.payload)
            return;
        var response = JSON.parse(message.payload);
        // As on the Applications page: SAM sends no "apps" while starting up,
        // and only the changed entries once subscribed.
        if (!response.returnValue || !response.apps)
            return;
        var list = [];
        for (var i = 0; i < response.apps.length; i++) {
            var app = response.apps[i];
            if (app && app.visible !== false && typeof app.id === "string" &&
                    /^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(app.id))
                list.push(app);
        }
        pageRoot.apps = list;
    }

    function setTweak(value) {
        var params = {"owner": pageRoot.tweakOwner};
        params[pageRoot.tweakKey] = value;
        luna.call("luna://org.webosports.service.tweaks.prefs/set", JSON.stringify(params),
                  _handleSetSuccess, _handleSetError);
    }
}
