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
import LuneOS.Forms 1.0

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
 *    OfonoContextConnection). APN contexts are listed, edited, added and
 *    removed here (OfonoConnMan.addContext/removeContext), MMS ones with
 *    their message center and proxy. The editor offers the access points
 *    ofono's provider database (provision.json) has for the SIM's network,
 *    and saves an active context by deactivating it first, since ofono
 *    takes no change to one that is active. There is no "reset to the
 *    operator's defaults": libqofono's resetContexts() calls ofono's
 *    DeactivateAll, not ResetContexts.
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
        loadApnDatabase();
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
                    color: Colors.error
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
                    color: Colors.secondaryText
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
                                    text: pageRoot.contextTypeLabel(apnCtx.type) + " · " + apnCtx.accessPointName
                                    elide: Text.ElideRight
                                    color: Colors.secondaryText
                                    font.pixelSize: FontUtils.sizeToPixels("small")
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    apnEditPopup.isNew = false;
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

                Button {
                    objectName: "apnAddButton"
                    width: parent.width
                    text: "Add Access Point"
                    enabled: connMan.valid && !pageRoot.addingContext
                    onClicked: {
                        // the editor opens on the new context once ofono reports it
                        pageRoot.apnError = "";
                        pageRoot.addingContext = true;
                        connMan.addContext("internet");
                    }
                }

                Label {
                    objectName: "apnListError"
                    width: parent.width
                    visible: pageRoot.apnError !== ""
                    text: pageRoot.apnError
                    wrapMode: Text.Wrap
                    color: "#e05050"
                    font.pixelSize: FontUtils.sizeToPixels("small")
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
                                          // telephonyd reports 0-5 bars (ofono's 0-100 Strength / 20),
                                          // the scale of the status bar's rssi-0 .. rssi-5 icons
                                          modelData.bars + "/5"
                                    color: Colors.secondaryText
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
                  "nearby networks to choose from. When editing an access " +
                  "point, the ones your operator is known to use can be " +
                  "picked from a list. Saving one that is in use reconnects " +
                  "mobile data."
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
    // The SIM whose contexts are listed: its MCC/MNC picks the operator's
    // access points out of the provider database below.
    OfonoSimManager {
        id: apnSim
        objectName: "apnSim"
        modemPath: modemManager.defaultModem
    }

    /*
     * ofono's own provider database (data/provision.json in its source, the
     * same data its provision.db is built from): every provider of a network
     * with all of its access points. When ofono sets a SIM up it keeps only
     * one access point per type; this lists the others to pick from.
     */
    property url apnDatabase: "file:///usr/share/ofono/provision.json"
    property var apnProviders: []
    function loadApnDatabase() {
        // a file:// XMLHttpRequest, allowed by QML_XHR_ALLOW_FILE_READ (set
        // for every webOS service and app in webos-global.conf)
        var req = new XMLHttpRequest();
        req.onreadystatechange = function() {
            if (req.readyState !== XMLHttpRequest.DONE)
                return;
            try {
                var list = JSON.parse(req.responseText);
                pageRoot.apnProviders = Array.isArray(list) ? list : [];
            } catch (e) {
                console.warn("No provider database at " + pageRoot.apnDatabase + ": " + e);
                pageRoot.apnProviders = [];
            }
        };
        req.open("GET", pageRoot.apnDatabase);
        req.send();
    }

    // The database's type for a context type: Initial attach uses the
    // internet access point.
    function apnUsageFor(contextType) {
        return contextType === "ia" ? "internet" : contextType;
    }

    // The access points of one context type for the SIM's network. A network
    // can have several providers (an operator and the brands on it): the
    // ones whose name or SPN is the SIM's come first, as ofono prefers them,
    // then the others in database order. Only the SIM's own network counts:
    // a brand listed under another one (Lebara NL still under Telfort's
    // 204/12, its SIMs now on KPN's 204/08) has that network's settings,
    // which do not work on this one.
    function apnChoices(contextType) {
        var usage = pageRoot.apnUsageFor(contextType);
        var mcc = apnSim.mobileCountryCode;
        var mnc = apnSim.mobileNetworkCode;
        var spn = (apnSim.serviceProviderName || "").toLowerCase();
        var own = [], others = [];
        if (!mcc || !mnc)
            return own;
        var id = mcc + mnc;
        for (var i = 0; i < pageRoot.apnProviders.length; i++) {
            var prov = pageRoot.apnProviders[i];
            if (!prov.ids || prov.ids.indexOf(id) < 0)
                continue;
            var mine = spn !== "" && ((prov.spn || "").toLowerCase() === spn ||
                                      (prov.name || "").toLowerCase() === spn);
            var bucket = mine ? own : others;
            var apns = prov.apns || [];
            for (var j = 0; j < apns.length; j++) {
                var a = apns[j];
                if (!a.type || a.type.indexOf(usage) < 0)
                    continue;
                bucket.push({
                    "label": a.name || prov.name,
                    "provider": prov.name,
                    "apn": a.apn || "",
                    "user": a.username || "",
                    "password": a.password || "",
                    "mmsc": a.mmsc || "",
                    "mmsproxy": a.mmsproxy || "",
                    "protocol": a.protocol || "",
                    "authentication": a.authentication || ""
                });
            }
        }
        return own.concat(others);
    }

    OfonoConnMan {
        id: connMan
        objectName: "apnConnMan"
        modemPath: modemManager.defaultModem

        onContextAdded: function(path) {
            if (!pageRoot.addingContext)
                return;
            pageRoot.addingContext = false;
            apnEditPopup.isNew = true;
            apnEditPopup.contextPath = path;
            apnEditPopup.open();
        }
        onReportError: function(errorString) {
            pageRoot.addingContext = false;
            if (apnEditPopup.opened)
                apnEditPopup.errorText = errorString;
            else
                pageRoot.apnError = errorString;
        }
    }

    // ofono's context types (src/gprs.c) and how they are shown
    readonly property var contextTypes: ["internet", "mms", "wap", "ims", "supl", "ia"]
    readonly property var contextTypeLabels: ["Internet", "MMS", "WAP", "IMS", "SUPL", "Initial attach"]
    property bool addingContext: false
    // a failed add or remove while the editor is closed
    property string apnError: ""

    function contextTypeLabel(type) {
        var i = contextTypes.indexOf(type);
        return i >= 0 ? contextTypeLabels[i] : type;
    }

    Popup {
        id: networkScanPopup

        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape

        width: Math.min(parent.width - Units.gu(4), Units.gu(46))
        height: Math.min(parent.height - Units.gu(4), Units.gu(56))

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
                    color: Colors.secondaryText
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
                                color: opInfo.status === "forbidden" ? Colors.error : Colors.secondaryText
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
        // keyboardTop: the window's height, or where the on-screen keys start
        height: Math.min(keyboardTop - Units.gu(4), Units.gu(44))

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
                    color: Colors.secondaryText
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }
                FormTextField {
                    id: pinField
                    Layout.fillWidth: true
                    height: Units.gu(5)
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhSensitiveData
                }

                Label {
                    Layout.fillWidth: true
                    visible: pinPromptPopup.mode === "change" || pinPromptPopup.mode === "puk"
                    text: "New PIN"
                    color: Colors.secondaryText
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }
                FormTextField {
                    id: newPinField
                    Layout.fillWidth: true
                    height: Units.gu(5)
                    visible: pinPromptPopup.mode === "change" || pinPromptPopup.mode === "puk"
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhSensitiveData
                }

                Label {
                    Layout.fillWidth: true
                    visible: pinPromptPopup.errorText !== ""
                    wrapMode: Text.WordWrap
                    text: pinPromptPopup.errorText
                    color: Colors.error
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
        objectName: "apnEditPopup"

        property string contextPath: ""
        // a context added for this editor: Cancel removes it again
        property bool isNew: false
        property string errorText: ""

        // The operator's access points for the type being edited.
        readonly property var presets: pageRoot.apnChoices(pageRoot.contextTypes[typeCombo.currentIndex])
        // What the list shows. Not bound to presets: that is worked out
        // again whenever a SIM property notifies, which ofono does while
        // the list is opening, and a ComboBox whose model is replaced while
        // its popup creates the rows crashes in Qt's text layout (Qt 6.12
        // on the Radon). So it only changes when the access points do, and
        // never while the list is open.
        property var shownPresets: []
        property var shownLabels: []
        function syncPresets() {
            if (presetCombo.popup.visible)
                return;
            var labels = presets.map(function(p) { return p.label + " (" + p.apn + ")"; });
            if (JSON.stringify(labels) === JSON.stringify(shownLabels))
                return;
            shownPresets = presets;
            shownLabels = labels;
            presetCombo.currentIndex = -1;
        }
        onPresetsChanged: syncPresets()
        // set from a chosen access point; the form has no field for it
        property string presetAuth: ""

        /*
         * Saving. ofono refuses every change but Active on an active context
         * (org.ofono.Error.InUse), so an active one is deactivated first, the
         * changed properties are written, and it is activated again. "" when
         * idle, else "deactivating", "writing" or "reactivating".
         */
        property string stage: ""
        readonly property bool saving: stage !== ""
        property var pending: ({})
        property int writesLeft: 0
        property bool writeFailed: false
        property string writeError: ""
        property bool reactivate: false
        property int retries: 0
        // a deactivation is done once ofono both answered it and reported
        // the context down, in whichever order those come
        property bool downSeen: false
        property bool downAnswered: false

        function desired() {
            var type = pageRoot.contextTypes[typeCombo.currentIndex];
            // Type first: ofono only takes MessageCenter/MessageProxy on an MMS context
            var keys = ["type"];
            var v = { "type": type };
            if (type === "mms") {
                v.messageCenter = mmsCenterField.text;
                v.messageProxy = mmsProxyField.text;
                keys.push("messageCenter", "messageProxy");
            }
            v.name = nameField.text;
            v.accessPointName = apnField.text;
            v.username = userField.text;
            v.password = passField.text;
            keys.push("name", "accessPointName", "username", "password");
            // none shown: the context's own is one the form does not know, or
            // had not arrived yet; leave it rather than write IPv4 over it
            if (protocolCombo.currentIndex >= 0) {
                v.protocol = ["ip", "ipv6", "dual"][protocolCombo.currentIndex];
                keys.push("protocol");
            }
            if (presetAuth !== "") {
                v.authMethod = presetAuth;
                keys.push("authMethod");
            }
            var changed = [];
            for (var i = 0; i < keys.length; i++) {
                if (editCtx[keys[i]] !== v[keys[i]])
                    changed.push({ "key": keys[i], "value": v[keys[i]] });
            }
            return changed;
        }

        function save() {
            errorText = "";
            retries = 0;
            pending = desired();
            if (pending.length === 0) {
                close();
                return;
            }
            reactivate = editCtx.active;
            if (editCtx.active)
                deactivate();
            else
                write();
        }
        function deactivate() {
            stage = "deactivating";
            downSeen = false;
            downAnswered = false;
            stageTimer.restart();
            editCtx.active = false;
        }
        function deactivated() {
            if (downSeen && downAnswered)
                write();
        }
        function write() {
            stage = "writing";
            stageTimer.restart();
            writeFailed = false;
            writeError = "";
            writesLeft = pending.length;
            for (var i = 0; i < pending.length; i++)
                editCtx[pending[i].key] = pending[i].value;
        }
        function written() {
            if (writeFailed) {
                // connman may bring the context back up between the
                // deactivation and the writes; take it down once more
                var left = desired();
                if (editCtx.active && retries < 1 && left.length > 0) {
                    retries++;
                    pending = left;
                    deactivate();
                    return;
                }
                errorText = writeError;
            }
            if (reactivate) {
                stage = "reactivating";
                stageTimer.restart();
                editCtx.active = true;
                return;
            }
            finish();
        }
        function finish() {
            stageTimer.stop();
            var ok = errorText === "";
            stage = "";
            if (ok)
                close();
        }

        Connections {
            target: editCtx
            function onActiveChanged() {
                if (apnEditPopup.stage === "deactivating" && !editCtx.active) {
                    apnEditPopup.downSeen = true;
                    apnEditPopup.deactivated();
                }
            }
            function onReportError(errorString) {
                if (apnEditPopup.stage === "writing") {
                    apnEditPopup.writeFailed = true;
                    apnEditPopup.writeError = errorString;
                } else if (apnEditPopup.stage === "deactivating") {
                    apnEditPopup.errorText = errorString;
                    apnEditPopup.finish();
                } else if (apnEditPopup.stage === "reactivating") {
                    apnEditPopup.errorText = "Saved, but it did not reconnect: " + errorString;
                    apnEditPopup.finish();
                }
            }
            function onSetPropertyFinished() {
                if (apnEditPopup.stage === "deactivating") {
                    apnEditPopup.downAnswered = true;
                    apnEditPopup.deactivated();
                } else if (apnEditPopup.stage === "writing") {
                    if (--apnEditPopup.writesLeft <= 0)
                        apnEditPopup.written();
                } else if (apnEditPopup.stage === "reactivating") {
                    apnEditPopup.finish();
                }
            }
        }
        Timer {
            id: stageTimer
            interval: 15000
            onTriggered: {
                if (apnEditPopup.stage === "deactivating")
                    apnEditPopup.errorText = "The access point did not disconnect, so it could not be changed.";
                else if (apnEditPopup.stage === "writing")
                    apnEditPopup.errorText = "oFono did not answer.";
                apnEditPopup.finish();
            }
        }

        // Fill the form from one of the operator's access points.
        function applyPreset(p) {
            nameField.text = p.label;
            apnField.text = p.apn;
            userField.text = p.user;
            passField.text = p.password;
            var proto = { "ip": 0, "ipv4": 0, "ipv6": 1, "ipv4v6": 2, "dual": 2 }[p.protocol];
            // The database rarely names one. ofono's provisiontool, Sailfish
            // and Droidian all take IPv4/IPv6 then for an internet access
            // point, and some networks refuse IPv4 alone (Lebara NL on KPN
            // answers it with an unspecified error).
            if (proto === undefined && (typeCombo.currentIndex === 0 || typeCombo.currentIndex === 5))
                proto = 2;
            if (proto !== undefined)
                protocolCombo.currentIndex = proto;
            // the database rarely names one; then ofono's own stays
            presetAuth = ["none", "pap", "chap"].indexOf(p.authentication) >= 0 ? p.authentication : "";
            if (typeCombo.currentIndex === 1) {
                mmsCenterField.text = p.mmsc;
                mmsProxyField.text = p.mmsproxy;
            }
        }

        modal: true
        focus: true
        closePolicy: saving ? Popup.NoAutoClose : Popup.CloseOnEscape

        width: Math.min(parent.width - Units.gu(4), Units.gu(46))
        // keyboardTop: the window's height, or where the on-screen keys start
        height: Math.min(keyboardTop - Units.gu(4), Units.gu(58))

        OfonoContextConnection {
            id: editCtx
            objectName: "apnEditContext"
            contextPath: apnEditPopup.contextPath
        }

        onOpened: {
            errorText = "";
            stage = "";
            presetAuth = "";
            presetCombo.currentIndex = -1;
            typeCombo.currentIndex = Math.max(0, pageRoot.contextTypes.indexOf(editCtx.type));
            mmsCenterField.text = editCtx.messageCenter;
            mmsProxyField.text = editCtx.messageProxy;
            nameField.text = editCtx.name;
            apnField.text = editCtx.accessPointName;
            userField.text = editCtx.username;
            passField.text = editCtx.password;
            protocolCombo.currentIndex = ["ip", "ipv6", "dual"].indexOf(editCtx.protocol);
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
                text: apnEditPopup.isNew ? "New Access Point" : "Edit Access Point"
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
                        text: "Type"
                        color: Colors.secondaryText
                        font.pixelSize: FontUtils.sizeToPixels("small")
                    }
                    ComboBox {
                        id: typeCombo
                        objectName: "apnTypeCombo"
                        Layout.fillWidth: true
                        model: pageRoot.contextTypeLabels

                        delegate: ItemDelegate {
                            width: typeCombo.width
                            text: modelData
                            font.weight: typeCombo.currentIndex === index ? Font.DemiBold : Font.Normal
                            checked: typeCombo.currentIndex === index
                        }
                        onActivated: presetCombo.currentIndex = -1
                    }

                    // Only there when the database knows this SIM's operator.
                    Label {
                        Layout.fillWidth: true
                        visible: apnEditPopup.shownLabels.length > 0
                        text: "Operator's access points"
                        color: Colors.secondaryText
                        font.pixelSize: FontUtils.sizeToPixels("small")
                    }
                    ComboBox {
                        id: presetCombo
                        objectName: "apnPresetCombo"
                        Layout.fillWidth: true
                        visible: apnEditPopup.shownLabels.length > 0
                        model: apnEditPopup.shownLabels
                        currentIndex: -1
                        displayText: currentIndex < 0 ? "Choose one to fill in the fields" : currentText
                        // a change that came while the list was open
                        popup.onClosed: apnEditPopup.syncPresets()

                        delegate: ItemDelegate {
                            id: presetRow
                            objectName: "apnPresetRow" + index
                            width: presetCombo.width
                            text: modelData
                            font.weight: presetCombo.currentIndex === index ? Font.DemiBold : Font.Normal
                            checked: presetCombo.currentIndex === index
                            // Not the style's text: that elides, and an access
                            // point's name and APN are often too long for one
                            // line. Qt 6.12 crashed (QTextLine::textStart in
                            // positionInlineImages, on the Radon) eliding it
                            // while the row was still being built and its width
                            // still followed the checkmark's. Wrapped instead,
                            // with a width that does not depend on the indicator.
                            contentItem: Text {
                                objectName: "apnPresetRowText"
                                text: presetRow.text
                                font: presetRow.font
                                color: presetRow.enabled ? "#333333" : "#646464"
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                                rightPadding: Units.gu(4)
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        onActivated: (index) => apnEditPopup.applyPreset(apnEditPopup.shownPresets[index])
                    }

                    Label {
                        Layout.fillWidth: true
                        text: "Name"
                        color: Colors.secondaryText
                        font.pixelSize: FontUtils.sizeToPixels("small")
                    }
                    FormTextField {
                        id: nameField
                        objectName: "apnNameField"
                        Layout.fillWidth: true
                        height: Units.gu(5)
                    }

                    Label {
                        Layout.fillWidth: true
                        text: "APN"
                        color: Colors.secondaryText
                        font.pixelSize: FontUtils.sizeToPixels("small")
                    }
                    FormTextField {
                        id: apnField
                        objectName: "apnApnField"
                        Layout.fillWidth: true
                        height: Units.gu(5)
                    }

                    Label {
                        Layout.fillWidth: true
                        text: "Username"
                        color: Colors.secondaryText
                        font.pixelSize: FontUtils.sizeToPixels("small")
                    }
                    FormTextField {
                        id: userField
                        Layout.fillWidth: true
                        height: Units.gu(5)
                    }

                    Label {
                        Layout.fillWidth: true
                        text: "Password"
                        color: Colors.secondaryText
                        font.pixelSize: FontUtils.sizeToPixels("small")
                    }
                    FormTextField {
                        id: passField
                        Layout.fillWidth: true
                        height: Units.gu(5)
                        echoMode: TextInput.Password
                    }

                    Label {
                        Layout.fillWidth: true
                        text: "Protocol"
                        color: Colors.secondaryText
                        font.pixelSize: FontUtils.sizeToPixels("small")
                    }
                    ComboBox {
                        id: protocolCombo
                        objectName: "apnProtocolCombo"
                        Layout.fillWidth: true
                        model: ["IPv4", "IPv6", "IPv4/IPv6"]
                        displayText: currentIndex < 0 ? "Unchanged" : currentText

                        delegate: ItemDelegate {
                            width: protocolCombo.width
                            text: modelData
                            font.weight: protocolCombo.currentIndex === index ? Font.DemiBold : Font.Normal
                            checked: protocolCombo.currentIndex === index
                        }
                    }

                    // only MMS contexts carry these (ofono: MessageCenter, MessageProxy)
                    Label {
                        Layout.fillWidth: true
                        visible: typeCombo.currentIndex === 1
                        text: "MMS center (MMSC URL)"
                        color: Colors.secondaryText
                        font.pixelSize: FontUtils.sizeToPixels("small")
                    }
                    FormTextField {
                        id: mmsCenterField
                        objectName: "apnMmsCenterField"
                        Layout.fillWidth: true
                        visible: typeCombo.currentIndex === 1
                        height: Units.gu(5)
                        inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
                    }

                    Label {
                        Layout.fillWidth: true
                        visible: typeCombo.currentIndex === 1
                        text: "MMS proxy (host:port)"
                        color: Colors.secondaryText
                        font.pixelSize: FontUtils.sizeToPixels("small")
                    }
                    FormTextField {
                        id: mmsProxyField
                        objectName: "apnMmsProxyField"
                        Layout.fillWidth: true
                        visible: typeCombo.currentIndex === 1
                        height: Units.gu(5)
                        inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
                    }
                }

                ScrollIndicator.vertical: ScrollIndicator { }
            }

            Label {
                objectName: "apnSavingText"
                Layout.fillWidth: true
                visible: apnEditPopup.saving
                text: apnEditPopup.reactivate ? "Saving; mobile data reconnects..." : "Saving..."
                wrapMode: Text.Wrap
                color: Colors.secondaryText
                font.pixelSize: FontUtils.sizeToPixels("small")
            }

            Label {
                objectName: "apnErrorText"
                Layout.fillWidth: true
                visible: apnEditPopup.errorText !== ""
                text: apnEditPopup.errorText
                wrapMode: Text.Wrap
                color: "#e05050"
                font.pixelSize: FontUtils.sizeToPixels("small")
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Units.gu(1)

                Button {
                    objectName: "apnCancelButton"
                    Layout.fillWidth: true
                    enabled: !apnEditPopup.saving
                    text: "Cancel"
                    LuneOSButton.mainColor: LuneOSButton.secondaryColor
                    onClicked: {
                        if (apnEditPopup.isNew)
                            connMan.removeContext(apnEditPopup.contextPath);
                        apnEditPopup.close();
                    }
                }
                Button {
                    objectName: "apnDeleteButton"
                    Layout.fillWidth: true
                    visible: !apnEditPopup.isNew
                    enabled: !apnEditPopup.saving
                    text: "Delete"
                    LuneOSButton.mainColor: LuneOSButton.negativeColor
                    onClicked: {
                        // ofono deactivates an active context before removing it
                        connMan.removeContext(apnEditPopup.contextPath);
                        apnEditPopup.close();
                    }
                }
                Button {
                    objectName: "apnSaveButton"
                    Layout.fillWidth: true
                    text: "Save"
                    enabled: !apnEditPopup.saving
                    LuneOSButton.mainColor: LuneOSButton.affirmativeColor
                    onClicked: apnEditPopup.save()
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
