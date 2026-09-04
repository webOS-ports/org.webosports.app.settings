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

/*
 * VPN, after the webOS 3.0.5 app of the same name (com.palm.app.vpn).
 *
 * Same page as the original: a list of profiles you tap to connect and swipe
 * to delete, an "Add profile..." row at the bottom of it, and a form behind
 * each profile whose fields depend on the connection type.
 *
 * What is different is what it talks to. The original drove com.palm.vpn,
 * which was HP's own service wrapping per-vendor VPN plugins that shipped
 * with the device. None of that exists any more. LuneOS has connman, and
 * connman has connman-vpnd, which already speaks OpenVPN, PPTP, L2TP,
 * OpenConnect, VPNC and WireGuard - what was missing was an LS2 service in
 * front of it, the way webos-connman-adapter sits in front of connman for
 * Wi-Fi. That service now exists: com.webos.service.vpn (luneos-vpn-adapter),
 * see luneos-vpn-api.md for the full contract this page drives -
 * getProfileList (subscribed, doubles as the connect-state feed),
 * getAgents/getAgentFormFields for the per-provider form, addProfile /
 * updateProfile / deleteProfile, connect / disconnect, and getStatus for the
 * credential prompts connman's own VPN agent role raises mid-connect
 * (relayed here rather than through a Connman QML UserAgent, the way Wi-Fi's
 * page does it - the agent role itself lives in the adapter, not in a D-Bus
 * interface this page could bind to directly).
 *
 * Unlike the legacy app, more than one profile can be connected at once
 * (SplitRouting decides how their routes coexist) - connecting a second one
 * does not disconnect the first.
 */
BasePage {
    id: pageRoot

    readonly property string vpnService: "com.webos.service.vpn"

    property bool serviceAvailable: false
    property var profiles: []
    property var types: []

    // Active net.connman.vpn.Agent.RequestInput prompt, if any - kept here
    // since one can arrive for a profile whose row is not even visible.
    property string activePromptId: ""

    Component.onCompleted: retrieveProperties();

    function _isConnected(state) {
        return state === "connected";
    }

    function _isBusy(state) {
        return state === "connecting" || state === "disconnecting" || state === "reconnecting";
    }

    function stateText(state) {
        if (state === "connected")
            return "Connected";
        if (state === "connecting")
            return "Connecting...";
        if (state === "reconnecting")
            return "Reconnecting...";
        if (state === "disconnecting")
            return "Disconnecting...";
        return "Not connected";
    }

    function agentLabel(vpnAgentGuid) {
        for (var i = 0; i < types.length; i++) {
            if (types[i].vpnAgentGuid === vpnAgentGuid)
                return types[i].vpnAgentLabel;
        }
        return vpnAgentGuid;
    }

    SettingsPageContent {
        ServiceUnavailableNotice {
            visible: !pageRoot.serviceAvailable

            serviceName: pageRoot.vpnService
            description: "connman on this device can carry a VPN, but the " +
                         vpnService + " service did not answer. Profiles " +
                         "cannot be stored or connected until it does."

            onRetry: pageRoot.retrieveProperties()
        }

        GroupBox {
            width: parent.width
            enabled: pageRoot.serviceAvailable

            title: "Choose a Profile"
            Column {
                width: parent.width

                Repeater {
                    model: pageRoot.profiles

                    delegate: Column {
                        width: parent.width

                        SwipeRow {
                            height: Units.gu(8)

                            LuneOSSwipeDelegate.confirmText: "Delete Profile"
                            LuneOSSwipeDelegate.onConfirmed:
                                pageRoot.removeProfile(modelData.vpnProfileName)

                            // Tapping the row connects or disconnects it, the
                            // way the original's list did.
                            onClicked: pageRoot.toggleConnection(modelData)

                            contentItem: RowLayout {
                                spacing: Units.gu(1)

                                Column {
                                    Layout.fillWidth: true

                                    Label {
                                        width: parent.width
                                        text: modelData.vpnProfileName
                                        elide: Text.ElideRight
                                        font.pixelSize: FontUtils.sizeToPixels("16pt")
                                    }
                                    Label {
                                        width: parent.width
                                        text: pageRoot.agentLabel(modelData.vpnAgentGuid) + " - " +
                                              pageRoot.stateText(modelData.vpnProfileConnectState)
                                        elide: Text.ElideRight
                                        color: pageRoot._isConnected(modelData.vpnProfileConnectState)
                                               ? "#3a7d1e" : "#666666"
                                        font.pixelSize: FontUtils.sizeToPixels("small")
                                    }
                                }

                                BusyIndicator {
                                    running: pageRoot._isBusy(modelData.vpnProfileConnectState)
                                    visible: running
                                    Layout.preferredWidth: Units.gu(4)
                                    Layout.preferredHeight: Units.gu(4)
                                }

                                // Opens the profile itself rather than
                                // connecting, which is what the original's
                                // detail arrow did. Config-provisioned
                                // profiles (Immutable) cannot be edited.
                                Button {
                                    text: "Edit"
                                    visible: !modelData.immutable
                                    LuneOSButton.mainColor: LuneOSButton.secondaryColor
                                    onClicked: pageRoot.editProfile(modelData)
                                }
                            }
                        }

                        HorizontalSeparator {
                            width: parent.width
                        }
                    }
                }

                Label {
                    width: parent.width
                    visible: pageRoot.profiles.length === 0
                    height: visible ? Units.gu(6) : 0
                    verticalAlignment: Text.AlignVCenter
                    text: "No profiles yet."
                    color: "#666666"
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }

                // Most VPN connections arrive as a ready-made file (a
                // WireGuard peer, a company's OpenVPN client) rather than a
                // list of fields to type in by hand, so importing is the
                // first option here, not something tucked under "Add".
                ItemDelegate {
                    width: parent.width
                    height: Units.gu(6)
                    text: "Import profile..."
                    font.pixelSize: FontUtils.sizeToPixels("16pt")

                    onClicked: pageRoot.importProfile()
                }

                ItemDelegate {
                    width: parent.width
                    height: Units.gu(6)
                    text: "Add profile manually..."
                    font.pixelSize: FontUtils.sizeToPixels("16pt")

                    onClicked: pageRoot.addProfile()
                }
            }
        }

        ExplanationText {
            text: "Tap a profile to connect or disconnect it. Swipe one sideways to delete it."
        }
    }

    VpnProfilePopup {
        id: profilePopup

        luna: pageRoot.luna
        types: pageRoot.types

        onSaved: (name, vpnAgentGuid, host, domain, vpnFormFields) =>
                     pageRoot.storeProfile(name, vpnAgentGuid, host, domain, vpnFormFields)
    }

    VpnPromptPopup {
        id: promptPopup

        luna: pageRoot.luna
        visible: false

        onClosed: pageRoot.activePromptId = ""
    }

    VpnImportProfilePopup {
        id: importPopup

        luna: pageRoot.luna
        visible: false
    }

    function addProfile() {
        profilePopup.profile = null;
        profilePopup.open();
    }

    function importProfile() {
        importPopup.open();
    }

    function editProfile(profile) {
        profilePopup.profile = profile;
        profilePopup.open();
    }

    function toggleConnection(profile) {
        if (_isBusy(profile.vpnProfileConnectState))
            return;

        if (_isConnected(profile.vpnProfileConnectState)) {
            _call("disconnect", {"vpnProfileName": profile.vpnProfileName});
            return;
        }

        _call("connect", {"vpnProfileName": profile.vpnProfileName}, _handleSetSuccess,
              _handleConnectError);
    }

    // errorCode -7 just means a credential prompt was raised - that prompt
    // already arrived (or is about to) via the getStatus subscription below,
    // so there is nothing extra to show here.
    function _handleConnectError(message) {
        var response = JSON.parse(message.payload);
        if (response.errorCode === -7)
            return;
        console.warn("VPN connect failed: " + (response.errorText || message.payload));
    }

    function storeProfile(name, vpnAgentGuid, host, domain, vpnFormFields) {
        var uri = profilePopup.editing ? "updateProfile" : "addProfile";
        _call(uri, {
            "vpnProfileName": name,
            "vpnAgentGuid": vpnAgentGuid,
            "vpnProfile": {
                "vpnHost": host,
                "vpnDomain": domain,
                "vpnFormFields": vpnFormFields
            }
        });
    }

    function removeProfile(name) {
        _call("deleteProfile", {"vpnProfileName": name});
    }

    /*
     * Bindings with LuneOS settings
     */
    function retrieveProperties() {
        luna.call("luna://" + vpnService + "/getAgents", "{}",
                  _handleGetAgents, _handleServiceUnavailable);

        // Subscribed: a connection going up or down has to move the row
        // without the page asking again.
        luna.subscribe("luna://" + vpnService + "/getProfileList",
                       JSON.stringify({"subscribe": true}),
                       _handleGetProfiles, _handleServiceUnavailable);

        // Subscribed: relays connman-vpnd's Agent.RequestInput prompts and
        // notices. Connection state changes are already covered by
        // getProfileList above.
        luna.subscribe("luna://" + vpnService + "/getStatus",
                       JSON.stringify({"subscribe": true}),
                       _handleStatusPush, _handleServiceUnavailable);
    }

    function _handleGetAgents(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue)
            return;

        pageRoot.types = response.vpnAgents !== undefined ? response.vpnAgents : [];
        pageRoot.serviceAvailable = true;
    }

    function _handleGetProfiles(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue)
            return;

        pageRoot.profiles = response.vpnProfiles !== undefined ? response.vpnProfiles : [];
        pageRoot.serviceAvailable = true;
    }

    function _handleStatusPush(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (response.returnValue === false)
            return;
        pageRoot.serviceAvailable = true;

        if (response.promptId === undefined)
            return;

        if (response.promptResolved) {
            if (response.promptId === pageRoot.activePromptId) {
                pageRoot.activePromptId = "";
                promptPopup.close();
            }
            return;
        }

        pageRoot.activePromptId = response.promptId;
        promptPopup.promptId = response.promptId;
        promptPopup.promptType = response.promptType || "form";
        promptPopup.label = response.label || "";
        promptPopup.vpnFormFields = response.vpnFormFields || [];
        promptPopup.open();
    }

    function _handleServiceUnavailable(message) {
        console.warn("VPN service did not answer: " + message);
        pageRoot.serviceAvailable = false;
    }

    function _call(method, params, successHandler, errorHandler) {
        luna.call("luna://" + pageRoot.vpnService + "/" + method,
                  JSON.stringify(params), successHandler || _handleSetSuccess,
                  errorHandler || _handleSetError);
    }
}
