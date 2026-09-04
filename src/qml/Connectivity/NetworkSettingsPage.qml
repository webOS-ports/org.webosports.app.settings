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
import QtQuick.Layouts 1.3

// Theme specific properties
import QtQuick.Controls.LuneOS 2.0
// Units & font sizes
import LunaNext.Common 0.1

import "../Common"

// The installed package registers this under the plain "QOfono" URI (see
// usr/lib/qml/QOfono/qmldir) - the plugin also accepts "MeeGo.QOfono", but
// nothing ships a MeeGo/QOfono path on-device, so that spelling only ever
// looks like it should work.
import QOfono 0.2

/*
 * Network Settings, the cellular/mobile counterpart to the separate WiFi and
 * Bluetooth pages. There was no single legacy webOS app this replaces - what
 * is here follows what SFOS, Droidian/GNOME, Furios/Phosh and UBports put on
 * their own equivalent pages: mobile data and roaming on/off, network mode,
 * automatic-vs-manual carrier selection, SIM PIN lock, access point names and
 * (only shown on a dual-SIM device) which SIM handles calls/SMS/data. USB
 * tethering and the WiFi hotspot are deliberately not here - on all four,
 * that lives in the WiFi panel instead, matching this app's own separate
 * WiFiPage.qml.
 *
 * Three different real backends, chosen per feature for whichever already
 * speaks it:
 *  - com.palm.wan (webos-telephonyd's wanservice.c) for the mobile
 *    data/roaming toggles - unchanged from what was already here.
 *  - com.palm.telephony (webos-telephonyd's telephonyservice_net.c/
 *    _simmgmt.c) for the radio access mode (ratQuery/ratSet) and, on a
 *    dual-SIM device, which SIM is the default for voice/SMS/data
 *    (simListQuery/defaultSimSet) - a webOS-specific policy layer that has
 *    no single-modem Ofono equivalent to bind to directly.
 *  - Direct MeeGo.QOfono bindings (already imported here for the operator/
 *    signal readout) for everything telephonyd does not cover at all:
 *    manual network scan/selection (OfonoNetworkRegistration/
 *    OfonoNetworkOperator), SIM PIN lock (OfonoSimManager, already declared
 *    below as `simManager`) and APN management (OfonoConnMan/
 *    OfonoContextConnection). APN contexts are read and edited here but not
 *    created or removed - libqofono's QML wrapper exposes no add/remove
 *    call, only editing whatever the SIM's own provider database already
 *    provisioned.
 */
BasePage {
    id: pageRoot

    /*
     * These alias properties summarize what settings are relative to this page
     */
    property alias roamingAllowed: roamingAllowedSwitch.checked
    property alias dataUsage: dataUsageSwitch.checked

    property bool wanServiceAvailable: false

    property bool ratSupported: true
    property string ratMode: "any"

    property bool simListAvailable: false
    property var sims: []
    property var defaultSim: ({ "voice": 0, "sms": 0, "data": 0 })
    readonly property bool dualSimPresent: pageRoot.sims.length > 1

    property bool pinLockEnabled: false
    // Which entry of modemManager.modems the SIM PIN section below talks to.
    // A single OfonoSimManager only ever speaks for one modem at a time, so
    // on a dual-SIM device this has to be a real choice - defaulting to
    // modemManager.defaultModem alone meant SIM 2's PIN could never be
    // reached from here at all.
    property int pinModemIndex: 0
    readonly property int pinSimSlot: pageRoot.pinModemIndex + 1

    // Prefers the names already fetched over com.palm.telephony
    // (simListQuery) so the picker reads "SIM 1"/"SIM 2" the same way the
    // Dual SIM section below does; falls back to a bare slot number if that
    // hasn't answered, or answered with a different SIM count than Ofono's
    // own modem list (they are two independent, not necessarily coherent,
    // views of the hardware).
    function pinSimNames() {
        var names = [];
        for (var i = 0; i < modemManager.modems.length; i++) {
            names.push(i < pageRoot.sims.length ? pageRoot.sims[i].name : "SIM " + (i + 1));
        }
        return names;
    }

    Component.onCompleted: {
        retrieveProperties();
    }

    // LabelAndSelector's ComboBox has no textRole of its own - plain names
    // for the model keep it working the same way it does for every other
    // LabelAndSelector in this app, rather than reintroducing the "ComboBox
    // is blind to an array-of-objects model without an explicit delegate"
    // bug this session already chased down once (see VpnProfilePopup.qml).
    function simNames() {
        return pageRoot.sims.map(function(s) { return s.name; });
    }

    function indexForSim(simId) {
        for (var i = 0; i < pageRoot.sims.length; i++) {
            if (pageRoot.sims[i].simId === simId)
                return i;
        }
        return 0;
    }

    function ratIndexForMode(mode) {
        var order = ["any", "gsm", "umts", "lte"];
        var idx = order.indexOf(mode);
        return idx === -1 ? 0 : idx;
    }

    SettingsPageContent {
        ServiceUnavailableNotice {
            visible: !pageRoot.wanServiceAvailable

            serviceName: "com.palm.wan"
            description: "Mobile data and roaming cannot be read or changed " +
                         "until this answers."

            onRetry: pageRoot.retrieveProperties()
        }

        GroupBox {
            width: parent.width

            title: "Mobile Data"
            Column {
                width: parent.width

                LabelAndSwitch {
                    id: dataUsageSwitch
                    label: "Mobile data"
                }
                HorizontalSeparator {
                    width: parent.width
                }
                LabelAndSwitch {
                    id: roamingAllowedSwitch
                    label: "Data roaming"
                }

                Column {
                    width: parent.width
                    visible: pageRoot.ratSupported

                    HorizontalSeparator {
                        width: parent.width
                    }
                    LabelAndSelector {
                        id: ratModeSelector
                        width: parent.width
                        label: "Network mode"
                        model: ["Automatic", "2G (GSM)", "3G (UMTS)", "4G (LTE)"]
                        currentIndex: pageRoot.ratIndexForMode(pageRoot.ratMode)

                        onActivated: (index) => {
                            var order = ["any", "gsm", "umts", "lte"];
                            luna.call("luna://com.palm.telephony/ratSet",
                                      JSON.stringify({"mode": order[index]}),
                                      _handleSetSuccess, _handleSetError);
                        }
                    }
                }
            }
        }

        GroupBox {
            width: parent.width

            title: "Carrier"
            Column {
                width: parent.width

                LabelAndValue {
                    width: parent.width
                    label: "Operator"
                    value: network.name
                }
                HorizontalSeparator {
                    width: parent.width
                }
                LabelAndValue {
                    width: parent.width
                    label: "Technology"
                    value: network.technology
                }
                HorizontalSeparator {
                    width: parent.width
                }
                LabelAndValue {
                    width: parent.width
                    label: "Strength"
                    value: network.strength
                }
                HorizontalSeparator {
                    width: parent.width
                }
                LabelAndValue {
                    width: parent.width
                    label: "Status"
                    value: network.status
                }
                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndSwitch {
                    id: automaticSelectionSwitch
                    label: "Automatic selection"

                    Connections {
                        target: network
                        function onModeChanged() {
                            automaticSelectionSwitch.checked = (network.mode === "auto");
                        }
                    }
                    Component.onCompleted: checked = (network.mode === "auto")

                    onClicked: {
                        if (checked) {
                            if (network.mode !== "auto")
                                network.registration();
                        } else if (network.mode !== "manual") {
                            networkScanPopup.open();
                        }
                    }
                }

                ItemDelegate {
                    width: parent.width
                    height: Units.gu(6)
                    visible: !automaticSelectionSwitch.checked
                    text: "Search networks..."
                    font.pixelSize: FontUtils.sizeToPixels("16pt")

                    onClicked: networkScanPopup.open()
                }
            }
        }

        GroupBox {
            width: parent.width

            title: "SIM PIN"
            Column {
                width: parent.width

                // Everything below binds to a single OfonoSimManager, which
                // only ever speaks for one modem at a time - on a dual-SIM
                // device that has to be a choice the user can actually make,
                // not just modemManager.defaultModem, or SIM 2's PIN could
                // never be reached at all here.
                LabelAndSelector {
                    width: parent.width
                    visible: modemManager.modems.length > 1
                    label: "SIM"
                    model: pageRoot.pinSimNames()
                    currentIndex: pageRoot.pinModemIndex
                    onActivated: (index) => pageRoot.pinModemIndex = index
                }
                LabelAndValue {
                    width: parent.width
                    visible: modemManager.modems.length === 1
                    label: "Applies to"
                    value: "SIM " + pageRoot.pinSimSlot +
                           (simManager.serviceProviderName ? " (" + simManager.serviceProviderName + ")" : "")
                }
                HorizontalSeparator {
                    width: parent.width
                    visible: modemManager.modems.length > 0
                }

                Label {
                    width: parent.width
                    visible: simManager.pinRequired === OfonoSimManager.SimPuk
                    wrapMode: Text.WordWrap
                    text: "The SIM is PUK-locked. Enter the PUK printed on " +
                          "the card it came with to unblock it."
                    color: "#be0003"
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }
                Button {
                    width: parent.width
                    visible: simManager.pinRequired === OfonoSimManager.SimPuk
                    text: "Unblock with PUK..."
                    LuneOSButton.mainColor: LuneOSButton.affirmativeColor
                    onClicked: {
                        pinPromptPopup.mode = "puk";
                        pinPromptPopup.open();
                    }
                }
                HorizontalSeparator {
                    width: parent.width
                    visible: simManager.pinRequired === OfonoSimManager.SimPuk
                }

                LabelAndSwitch {
                    id: pinLockSwitch
                    label: "Lock SIM with PIN"
                    checked: pageRoot.pinLockEnabled

                    onClicked: {
                        pinPromptPopup.mode = checked ? "enable" : "disable";
                        pinPromptPopup.open();
                    }
                }
                HorizontalSeparator {
                    width: parent.width
                }
                ItemDelegate {
                    width: parent.width
                    height: Units.gu(6)
                    enabled: pageRoot.pinLockEnabled
                    text: "Change PIN..."
                    font.pixelSize: FontUtils.sizeToPixels("16pt")

                    onClicked: {
                        pinPromptPopup.mode = "change";
                        pinPromptPopup.open();
                    }
                }
            }
        }

        GroupBox {
            width: parent.width

            title: "Access Point Names"
            Column {
                width: parent.width

                Label {
                    width: parent.width
                    visible: connMan.contexts.length === 0
                    height: visible ? Units.gu(6) : 0
                    verticalAlignment: Text.AlignVCenter
                    text: "No access points configured."
                    color: "#666666"
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }

                Repeater {
                    model: connMan.contexts

                    delegate: Column {
                        width: parent.width

                        readonly property string contextPath: modelData

                        OfonoContextConnection {
                            id: apnCtx
                            contextPath: modelData
                        }

                        Item {
                            width: parent.width
                            height: Units.gu(7)

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Units.gu(1)
                                anchors.rightMargin: Units.gu(1)

                                Label {
                                    width: parent.width
                                    text: (apnCtx.name || apnCtx.accessPointName) +
                                          (apnCtx.active ? "  • Active" : "")
                                    elide: Text.ElideRight
                                    font.pixelSize: FontUtils.sizeToPixels("16pt")
                                }
                                Label {
                                    width: parent.width
                                    text: apnCtx.accessPointName
                                    elide: Text.ElideRight
                                    color: "#666666"
                                    font.pixelSize: FontUtils.sizeToPixels("small")
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    apnEditPopup.contextPath = modelData;
                                    apnEditPopup.open();
                                }
                            }
                        }

                        HorizontalSeparator {
                            width: parent.width
                        }
                    }
                }
            }
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.dualSimPresent

            title: "Dual SIM"
            Column {
                width: parent.width

                Repeater {
                    model: pageRoot.sims

                    delegate: Column {
                        width: parent.width

                        Item {
                            width: parent.width
                            height: Units.gu(7)

                            Column {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Units.gu(1)

                                Label {
                                    text: modelData.name
                                    font.pixelSize: FontUtils.sizeToPixels("16pt")
                                }
                                Label {
                                    text: modelData.operatorName + " · " +
                                          modelData.bars + "/4"
                                    color: "#666666"
                                    font.pixelSize: FontUtils.sizeToPixels("small")
                                }
                            }

                            Switch {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.rightMargin: Units.gu(1)
                                checked: modelData.powered

                                onClicked: pageRoot._call("powerSet",
                                    {"simId": modelData.simId, "state": checked ? "on" : "off"})
                            }
                        }

                        HorizontalSeparator {
                            width: parent.width
                        }
                    }
                }

                LabelAndSelector {
                    id: voiceSimSelector
                    width: parent.width
                    label: "Calls"
                    model: pageRoot.simNames()
                    currentIndex: pageRoot.indexForSim(pageRoot.defaultSim.voice)
                    onActivated: (index) => pageRoot._call("defaultSimSet",
                        {"voice": pageRoot.sims[index].simId})
                }

                LabelAndSelector {
                    id: smsSimSelector
                    width: parent.width
                    label: "Messages"
                    model: pageRoot.simNames()
                    currentIndex: pageRoot.indexForSim(pageRoot.defaultSim.sms)
                    onActivated: (index) => pageRoot._call("defaultSimSet",
                        {"sms": pageRoot.sims[index].simId})
                }

                LabelAndSelector {
                    id: dataSimSelector
                    width: parent.width
                    label: "Mobile data"
                    model: pageRoot.simNames()
                    currentIndex: pageRoot.indexForSim(pageRoot.defaultSim.data)
                    onActivated: (index) => pageRoot._call("defaultSimSet",
                        {"data": pageRoot.sims[index].simId})
                }
            }
        }

        ExplanationText {
            text: "Switching to manual carrier selection opens a scan of " +
                  "nearby networks to choose from. An access point cannot " +
                  "be added or removed here, only edited - the SIM's own " +
                  "provider already set up whatever is listed."
        }
    }

    OfonoManager {
        id: modemManager
    }
    OfonoSimManager {
        id: simManager
        modemPath: modemManager.modems.length > pageRoot.pinModemIndex ?
                   modemManager.modems[pageRoot.pinModemIndex] : modemManager.defaultModem

        onLockedPinsChanged: pageRoot.pinLockEnabled = lockedPins.indexOf(OfonoSimManager.SimPin) !== -1
        Component.onCompleted: pageRoot.pinLockEnabled = lockedPins.indexOf(OfonoSimManager.SimPin) !== -1
        // lockedPins only re-emits when the *value* changes - switching to a
        // SIM that happens to share the same locked/unlocked state as the
        // last one would otherwise leave pinLockEnabled (and so the switch)
        // showing the previous SIM's state under the new SIM's label.
        onModemPathChanged: pageRoot.pinLockEnabled = lockedPins.indexOf(OfonoSimManager.SimPin) !== -1

        onLockPinComplete: (error, errorString) => {
            if (error !== OfonoSimManager.NoError) {
                pinPromptPopup.errorText = errorString || "Could not enable the PIN lock.";
                pinLockSwitch.checked = pageRoot.pinLockEnabled;
                return;
            }
            pageRoot.pinLockEnabled = true;
            pinPromptPopup.close();
        }
        onUnlockPinComplete: (error, errorString) => {
            if (error !== OfonoSimManager.NoError) {
                pinPromptPopup.errorText = errorString || "Could not disable the PIN lock.";
                pinLockSwitch.checked = pageRoot.pinLockEnabled;
                return;
            }
            pageRoot.pinLockEnabled = false;
            pinPromptPopup.close();
        }
        onChangePinComplete: (error, errorString) => {
            if (error !== OfonoSimManager.NoError) {
                pinPromptPopup.errorText = errorString || "Could not change the PIN.";
                return;
            }
            pinPromptPopup.close();
        }
        onResetPinComplete: (error, errorString) => {
            if (error !== OfonoSimManager.NoError) {
                pinPromptPopup.errorText = errorString || "Could not unblock the SIM.";
                return;
            }
            pinPromptPopup.close();
        }
    }
    OfonoModem {
        id: modem
        modemPath: modemManager.defaultModem
    }
    OfonoNetworkRegistration {
        id: network
        modemPath: modemManager.defaultModem
    }
    OfonoConnMan {
        id: connMan
        modemPath: modemManager.defaultModem
    }

    Popup {
        id: networkScanPopup

        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape

        width: Math.min(parent.width - Units.gu(4), Units.gu(46))
        height: Math.min(parent.height - Units.gu(4), Units.gu(56))
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        onOpened: network.scan()

        Item {
            anchors.fill: parent

            ColumnLayout {
                anchors.fill: parent
                spacing: Units.gu(1.5)

                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "Choose a Network"
                    font.pixelSize: FontUtils.sizeToPixels("18pt")
                    font.weight: Font.Bold
                }

                BusyIndicator {
                    Layout.alignment: Qt.AlignHCenter
                    running: network.scanning
                    visible: running
                }

                Label {
                    Layout.fillWidth: true
                    visible: !network.scanning && network.networkOperators.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "No networks found."
                    color: "#666666"
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: !network.scanning && network.networkOperators.length > 0
                    clip: true

                    model: network.networkOperators

                    delegate: Item {
                        id: opRow
                        width: ListView.view.width
                        height: Units.gu(7)

                        readonly property string opPath: modelData

                        OfonoNetworkOperator {
                            id: opInfo
                            operatorPath: modelData
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Units.gu(1)
                            anchors.rightMargin: Units.gu(1)

                            Label {
                                width: parent.width
                                text: opInfo.name
                                elide: Text.ElideRight
                                font.pixelSize: FontUtils.sizeToPixels("16pt")
                                font.weight: opInfo.status === "current" ? Font.DemiBold : Font.Normal
                            }
                            Label {
                                width: parent.width
                                text: opInfo.status === "current" ? "Current" :
                                      opInfo.status === "forbidden" ? "Forbidden" : "Available"
                                elide: Text.ElideRight
                                color: opInfo.status === "forbidden" ? "#be0003" : "#666666"
                                font.pixelSize: FontUtils.sizeToPixels("small")
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: opInfo.status !== "forbidden"
                            onClicked: {
                                opInfo.registerOperator();
                                networkScanPopup.close();
                            }
                        }

                        HorizontalSeparator {
                            anchors.bottom: parent.bottom
                            width: parent.width
                        }
                    }

                    ScrollIndicator.vertical: ScrollIndicator { }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Units.gu(1)

                    Button {
                        Layout.fillWidth: true
                        text: "Rescan"
                        enabled: !network.scanning
                        LuneOSButton.mainColor: LuneOSButton.secondaryColor
                        onClicked: network.scan()
                    }
                    Button {
                        Layout.fillWidth: true
                        text: "Cancel"
                        LuneOSButton.mainColor: LuneOSButton.secondaryColor
                        onClicked: networkScanPopup.close()
                    }
                }
            }
        }
    }

    Popup {
        id: pinPromptPopup

        // "enable"/"disable" ask for the current PIN (lockPin/unlockPin),
        // "change" asks for the old and a new PIN, "puk" asks for the PUK
        // printed on the SIM's card plus a new PIN to replace it with.
        property string mode: "enable"
        property string errorText: ""

        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape

        width: Math.min(parent.width - Units.gu(4), Units.gu(40))
        height: Math.min(parent.height - Units.gu(4), Units.gu(44))
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        onOpened: {
            errorText = "";
            pinField.text = "";
            newPinField.text = "";
        }
        onClosed: {
            if (mode === "enable" || mode === "disable")
                pinLockSwitch.checked = pageRoot.pinLockEnabled;
        }

        Item {
            anchors.fill: parent

            ColumnLayout {
                width: parent.width
                spacing: Units.gu(1.5)

                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: pinPromptPopup.mode === "enable" ? "Enable PIN Lock" :
                          pinPromptPopup.mode === "disable" ? "Disable PIN Lock" :
                          pinPromptPopup.mode === "change" ? "Change PIN" : "Unblock SIM"
                    font.pixelSize: FontUtils.sizeToPixels("18pt")
                    font.weight: Font.Bold
                }

                Label {
                    Layout.fillWidth: true
                    text: pinPromptPopup.mode === "puk" ? "PUK code" :
                          pinPromptPopup.mode === "change" ? "Current PIN" : "PIN"
                    color: "#666666"
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }
                TextField {
                    id: pinField
                    Layout.fillWidth: true
                    height: Units.gu(5)
                    leftPadding: Units.gu(1)
                    rightPadding: Units.gu(1)
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhSensitiveData
                    color: "#2a2929"
                    background: Rectangle {
                        color: "#ffffff"
                        radius: Units.gu(0.6)
                        border.color: "#9a9a9a"
                        border.width: 1
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: pinPromptPopup.mode === "change" || pinPromptPopup.mode === "puk"
                    text: "New PIN"
                    color: "#666666"
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }
                TextField {
                    id: newPinField
                    Layout.fillWidth: true
                    height: Units.gu(5)
                    visible: pinPromptPopup.mode === "change" || pinPromptPopup.mode === "puk"
                    leftPadding: Units.gu(1)
                    rightPadding: Units.gu(1)
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhSensitiveData
                    color: "#2a2929"
                    background: Rectangle {
                        color: "#ffffff"
                        radius: Units.gu(0.6)
                        border.color: "#9a9a9a"
                        border.width: 1
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: pinPromptPopup.errorText !== ""
                    wrapMode: Text.WordWrap
                    text: pinPromptPopup.errorText
                    color: "#be0003"
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Units.gu(1)

                    Button {
                        Layout.fillWidth: true
                        text: "Cancel"
                        LuneOSButton.mainColor: LuneOSButton.secondaryColor
                        onClicked: pinPromptPopup.close()
                    }
                    Button {
                        Layout.fillWidth: true
                        text: "OK"
                        LuneOSButton.mainColor: LuneOSButton.affirmativeColor
                        enabled: pinField.text !== "" &&
                                 ((pinPromptPopup.mode !== "change" && pinPromptPopup.mode !== "puk") ||
                                  newPinField.text !== "")
                        onClicked: {
                            if (pinPromptPopup.mode === "enable")
                                simManager.lockPin(OfonoSimManager.SimPin, pinField.text);
                            else if (pinPromptPopup.mode === "disable")
                                simManager.unlockPin(OfonoSimManager.SimPin, pinField.text);
                            else if (pinPromptPopup.mode === "change")
                                simManager.changePin(OfonoSimManager.SimPin, pinField.text, newPinField.text);
                            else
                                simManager.resetPin(OfonoSimManager.SimPuk, pinField.text, newPinField.text);
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: apnEditPopup

        property string contextPath: ""

        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape

        width: Math.min(parent.width - Units.gu(4), Units.gu(46))
        height: Math.min(parent.height - Units.gu(4), Units.gu(58))
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        OfonoContextConnection {
            id: editCtx
            contextPath: apnEditPopup.contextPath
        }

        onOpened: {
            nameField.text = editCtx.name;
            apnField.text = editCtx.accessPointName;
            userField.text = editCtx.username;
            passField.text = editCtx.password;
            protocolCombo.currentIndex = ["ip", "ipv6", "dual"].indexOf(editCtx.protocol);
            if (protocolCombo.currentIndex === -1)
                protocolCombo.currentIndex = 0;
        }

        // The form is taller than a fixed-height popup can always guarantee
        // (four fields plus labels, before even reaching the buttons) - a
        // plain ColumnLayout inside an anchors.fill Item does not clip or
        // scroll, so on a shorter screen the Save/Cancel row was rendered
        // past the bottom of the popup's own background image entirely.
        // Keeping the title and the buttons outside the ScrollView means
        // they are always on screen; only the fields in between scroll.
        ColumnLayout {
            anchors.fill: parent
            spacing: Units.gu(1.5)

            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "Edit Access Point"
                font.pixelSize: FontUtils.sizeToPixels("18pt")
                font.weight: Font.Bold
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: formColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                // A ScrollView's vertical ScrollBar reserves its own width
                // out of the content next to it in this style, which is
                // exactly what made the right margin here wider than the
                // left one - a plain Flickable with a ScrollIndicator (the
                // same pairing networkScanPopup's own list and
                // FilePickerPopup.qml already use) overlays instead, so the
                // fields keep the same width the fixed title/buttons above
                // and below them already have.
                ColumnLayout {
                    id: formColumn
                    width: parent.width
                    spacing: Units.gu(1.5)

                    Label {
                        Layout.fillWidth: true
                        text: "Name"
                        color: "#666666"
                        font.pixelSize: FontUtils.sizeToPixels("small")
                    }
                    TextField {
                        id: nameField
                        Layout.fillWidth: true
                        height: Units.gu(5)
                        leftPadding: Units.gu(1)
                        rightPadding: Units.gu(1)
                        color: "#2a2929"
                        background: Rectangle {
                            color: "#ffffff"; radius: Units.gu(0.6)
                            border.color: "#9a9a9a"; border.width: 1
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: "APN"
                        color: "#666666"
                        font.pixelSize: FontUtils.sizeToPixels("small")
                    }
                    TextField {
                        id: apnField
                        Layout.fillWidth: true
                        height: Units.gu(5)
                        leftPadding: Units.gu(1)
                        rightPadding: Units.gu(1)
                        color: "#2a2929"
                        background: Rectangle {
                            color: "#ffffff"; radius: Units.gu(0.6)
                            border.color: "#9a9a9a"; border.width: 1
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: "Username"
                        color: "#666666"
                        font.pixelSize: FontUtils.sizeToPixels("small")
                    }
                    TextField {
                        id: userField
                        Layout.fillWidth: true
                        height: Units.gu(5)
                        leftPadding: Units.gu(1)
                        rightPadding: Units.gu(1)
                        color: "#2a2929"
                        background: Rectangle {
                            color: "#ffffff"; radius: Units.gu(0.6)
                            border.color: "#9a9a9a"; border.width: 1
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: "Password"
                        color: "#666666"
                        font.pixelSize: FontUtils.sizeToPixels("small")
                    }
                    TextField {
                        id: passField
                        Layout.fillWidth: true
                        height: Units.gu(5)
                        leftPadding: Units.gu(1)
                        rightPadding: Units.gu(1)
                        echoMode: TextInput.Password
                        color: "#2a2929"
                        background: Rectangle {
                            color: "#ffffff"; radius: Units.gu(0.6)
                            border.color: "#9a9a9a"; border.width: 1
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: "Protocol"
                        color: "#666666"
                        font.pixelSize: FontUtils.sizeToPixels("small")
                    }
                    ComboBox {
                        id: protocolCombo
                        Layout.fillWidth: true
                        model: ["IPv4", "IPv6", "IPv4/IPv6"]

                        delegate: ItemDelegate {
                            width: protocolCombo.width
                            text: modelData
                            font.weight: protocolCombo.currentIndex === index ? Font.DemiBold : Font.Normal
                            checked: protocolCombo.currentIndex === index
                        }
                    }
                }

                ScrollIndicator.vertical: ScrollIndicator { }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Units.gu(1)

                Button {
                    Layout.fillWidth: true
                    text: "Cancel"
                    LuneOSButton.mainColor: LuneOSButton.secondaryColor
                    onClicked: apnEditPopup.close()
                }
                Button {
                    Layout.fillWidth: true
                    text: "Save"
                    LuneOSButton.mainColor: LuneOSButton.affirmativeColor
                    onClicked: {
                        editCtx.name = nameField.text;
                        editCtx.accessPointName = apnField.text;
                        editCtx.username = userField.text;
                        editCtx.password = passField.text;
                        editCtx.protocol = ["ip", "ipv6", "dual"][protocolCombo.currentIndex];
                        apnEditPopup.close();
                    }
                }
            }
        }
    }

    /*
     * Bindings with LuneOS settings
     */
    function retrieveProperties() {
        luna.subscribe("luna://com.palm.wan/getstatus", '{"subscribe": true}', _handleWanStatus, _handleGetError);

        luna.call("luna://com.palm.telephony/ratQuery", "{}", _handleRatQuery, _handleRatUnavailable);

        luna.subscribe("luna://com.palm.telephony/simListQuery",
                        JSON.stringify({"subscribe": true}), _handleSimList, _handleSimListUnavailable);
    }
    function _handleWanStatus(message) {
        if(message && message.payload) {
            let payloadValue = JSON.parse(message.payload);
            if(typeof payloadValue.roamguard !== 'undefined') {
                roamingAllowed = (payloadValue.roamguard === "disable");
            }
            if(typeof payloadValue.disablewan !== 'undefined') {
                dataUsage = (payloadValue.disablewan === "off");
            }
            pageRoot.wanServiceAvailable = true;
        }
    }
    function _handleGetError(message) {
        console.warn("com.palm.wan did not answer: " + message);
        pageRoot.wanServiceAvailable = false;
    }

    function _handleRatQuery(message) {
        if (!message || !message.payload)
            return;
        var response = JSON.parse(message.payload);
        if (!response.returnValue || !response.extended)
            return;
        pageRoot.ratMode = response.extended.mode || "any";
    }
    function _handleRatUnavailable(message) {
        // No implementation on this modem - the mode picker degrades away
        // rather than offering a control that will only ever error out.
        pageRoot.ratSupported = false;
    }

    function _handleSimList(message) {
        if (!message || !message.payload)
            return;
        var response = JSON.parse(message.payload);
        if (!response.returnValue)
            return;
        pageRoot.sims = response.sims !== undefined ? response.sims : [];
        pageRoot.defaultSim = response.defaultSim !== undefined ? response.defaultSim : pageRoot.defaultSim;
        pageRoot.simListAvailable = true;
    }
    function _handleSimListUnavailable(message) {
        pageRoot.simListAvailable = false;
    }

    function _handleSetSuccess(message) {
    }
    function _handleSetError(message) {
        console.warn("Network settings call failed: " + message);
    }

    function _call(method, params) {
        luna.call("luna://com.palm.telephony/" + method, JSON.stringify(params),
                  _handleSetSuccess, _handleSetError);
    }

    onRoamingAllowedChanged: {
        var roamguard = roamingAllowed ? "disable" : "enable"
        luna.call("luna://com.palm.wan/set", '{"roamguard": "'+roamguard+'"}', _handleSetSuccess, _handleSetError);
    }
    onDataUsageChanged: {
        var disablewan = dataUsage ? "off" : "on"
        luna.call("luna://com.palm.wan/set", '{"disablewan": "'+disablewan+'"}', _handleSetSuccess, _handleSetError);
    }
}
