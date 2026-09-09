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
import QtQuick.Layouts 1.3

// Theme specific properties
import QtQuick.Controls.LuneOS 2.0
// Units & font sizes
import LunaNext.Common 0.1
// Connman
import Connman 0.2

import "../Common"

/*
 * What one Wi-Fi network actually is and, once connected, how it is
 * configured - the legacy app's "config" scene, which it pushed when you
 * tapped a network you were already on (its "Access Point Info" group behind
 * the app menu held BSSID / Signal / Channel, and the "IP address" group the
 * addressing). Here it hangs off press-and-hold instead, so it works for any
 * network in the list and leaves plain tap as connect/disconnect.
 *
 * Everything comes off the NetworkService the list delegate was showing, so
 * it stays live while open: connect from underneath the popup and the
 * addressing fills itself in.
 *
 * Rows are built as lists rather than written out one by one because how
 * much there is to say varies: a network that is not up has no addressing to
 * report at all, and which of the rest connman knows depends on how far it
 * has got with it. Empty rows are dropped instead of being shown blank, and
 * a group left with no rows hides itself.
 */
Popup {
    id: networkInfoPopup

    property NetworkService service: null

    modal: true
    dim: true
    focus: true
    // Nothing here is being edited, so dismissing it by tapping away is
    // safe and is the quicker way out of a page you only opened to read.
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    width: Math.min(parent.width - Units.gu(4), Units.gu(46))
    height: Math.min(parent.height - Units.gu(4), Units.gu(70))
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    /*
     * The service is owned by the TechnologyModel, which drops services that
     * fall out of range on a rescan. QML nulls an object property when the
     * object behind it goes away, so rather than keep showing a frozen page
     * of a network that no longer exists, close.
     */
    onServiceChanged: if (!service) close();

    // "psk" and friends off the wire are not what you want to read.
    function _securityName(securityType) {
        switch (securityType) {
        case NetworkService.SecurityNone:    return "Open (none)";
        case NetworkService.SecurityWEP:     return "WEP";
        case NetworkService.SecurityPSK:     return "WPA/WPA2 Personal";
        case NetworkService.SecurityIEEE802: return "802.1X Enterprise";
        default:                             return "";
        }
    }

    /*
     * connman reports the connection state, not a sentence. "ready" means
     * connected, "online" means connected and its own connectivity check
     * reached the internet - worth keeping apart, it is exactly the
     * difference between a working network and a captive portal.
     */
    function _stateName(state) {
        switch (state) {
        case "idle":          return "Not connected";
        case "association":   return "Associating…";
        case "configuration": return "Getting an IP address…";
        case "ready":         return "Connected";
        case "online":        return "Connected – internet available";
        case "disconnect":    return "Disconnecting…";
        case "failure":       return "Connection failed";
        default:              return "";
        }
    }

    // Frequency (MHz) -> channel number. Deliberately silent outside the
    // ranges where the arithmetic is exact, rather than printing a made-up
    // channel for a band this does not know about.
    function _channel(frequency) {
        if (frequency === 2484)                            return 14;  // 2.4GHz, Japan
        if (frequency >= 2412 && frequency <= 2472)        return (frequency - 2407) / 5;
        if (frequency >= 5160 && frequency <= 5885)        return (frequency - 5000) / 5;
        if (frequency >= 5955 && frequency <= 7115)        return (frequency - 5950) / 5;  // 6GHz
        return 0;
    }

    function _bandName(frequency) {
        if (frequency >= 2400 && frequency < 2500) return "2.4 GHz";
        if (frequency >= 4900 && frequency < 5900) return "5 GHz";
        if (frequency >= 5900 && frequency < 7200) return "6 GHz";
        return "";
    }

    // A QVariantMap arrives as a plain object, and is simply empty for a
    // service that has none of that kind of configuration yet.
    function _mapValue(map, key) {
        if (!map)
            return "";
        var value = map[key];
        return (value === undefined || value === null) ? "" : String(value);
    }

    function _listValue(list) {
        return list ? list.join(", ") : "";
    }

    function _addRow(rows, label, value) {
        if (value !== "" && value !== undefined && value !== null)
            rows.push({"rowLabel": label, "rowValue": String(value)});
    }

    readonly property bool forgettable: !!service && (service.saved || service.favorite)

    readonly property var accessPointRows: {
        var rows = [];
        if (!service)
            return rows;

        _addRow(rows, "Signal", service.strength + "%");
        _addRow(rows, "Security", _securityName(service.securityType));
        // Only meaningful on a secured network, and connman leaves it empty
        // until it has associated and knows the cipher in use.
        _addRow(rows, "Encryption", service.encryptionMode.toUpperCase());
        _addRow(rows, "BSSID", service.bssid);

        var channel = _channel(service.frequency);
        var band = _bandName(service.frequency);
        if (channel > 0)
            _addRow(rows, "Channel", band !== "" ? channel + " (" + band + ")" : String(channel));
        if (service.frequency > 0)
            _addRow(rows, "Frequency", service.frequency + " MHz");

        // connman reports MaxRate in bit/s.
        if (service.maxRate > 0)
            _addRow(rows, "Max speed", Math.round(service.maxRate / 1000000) + " Mbps");

        if (service.hidden)
            _addRow(rows, "Hidden network", "Yes");

        return rows;
    }

    readonly property var addressingRows: {
        var rows = [];
        if (!service)
            return rows;

        var ipv4 = service.ipv4;
        var method = _mapValue(ipv4, "Method");
        if (method === "dhcp")        _addRow(rows, "Configuration", "Automatic (DHCP)");
        else if (method === "manual") _addRow(rows, "Configuration", "Manual");
        else if (method === "off")    _addRow(rows, "Configuration", "Off");

        _addRow(rows, "IP address", _mapValue(ipv4, "Address"));
        _addRow(rows, "Subnet mask", _mapValue(ipv4, "Netmask"));
        _addRow(rows, "Gateway", _mapValue(ipv4, "Gateway"));

        var ipv6 = service.ipv6;
        var ipv6Address = _mapValue(ipv6, "Address");
        var prefixLength = _mapValue(ipv6, "PrefixLength");
        if (ipv6Address !== "")
            _addRow(rows, "IPv6 address",
                    prefixLength !== "" ? ipv6Address + "/" + prefixLength : ipv6Address);
        _addRow(rows, "IPv6 gateway", _mapValue(ipv6, "Gateway"));

        _addRow(rows, "DNS", _listValue(service.nameservers));
        _addRow(rows, "Search domains", _listValue(service.domains));

        var proxyMethod = _mapValue(service.proxy, "Method");
        if (proxyMethod === "manual")
            _addRow(rows, "Proxy", _listValue(service.proxy["Servers"]));
        else if (proxyMethod === "auto")
            _addRow(rows, "Proxy", _mapValue(service.proxy, "URL") || "Automatic");

        return rows;
    }

    readonly property var interfaceRows: {
        var rows = [];
        if (!service)
            return rows;

        var ethernet = service.ethernet;
        _addRow(rows, "Interface", _mapValue(ethernet, "Interface"));
        // ConnMan's "Address" here is this device's MAC, not the AP's.
        _addRow(rows, "MAC address", _mapValue(ethernet, "Address"));
        _addRow(rows, "MTU", _mapValue(ethernet, "MTU"));

        return rows;
    }

    // The groups are identical in shape, so they are laid out from a list
    // rather than written out three times over.
    readonly property var infoGroups: [
        {"groupTitle": "Access Point Info", "groupRows": accessPointRows},
        {"groupTitle": "IP Address",        "groupRows": addressingRows},
        {"groupTitle": "Interface",         "groupRows": interfaceRows}
    ]

    ColumnLayout {
        anchors.fill: parent
        spacing: Units.gu(1)

        Label {
            Layout.fillWidth: true
            text: networkInfoPopup.service ? networkInfoPopup.service.name : ""
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.pixelSize: FontUtils.sizeToPixels("18pt")
            font.weight: Font.Bold
        }

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: FontUtils.sizeToPixels("small")
            // A failure is the one state that carries a reason with it, and
            // it is the only time anyone reads this line closely.
            color: networkInfoPopup.service && networkInfoPopup.service.state === "failure"
                   ? "#be0003" : "#666666"
            text: {
                if (!networkInfoPopup.service)
                    return "";
                var state = networkInfoPopup._stateName(networkInfoPopup.service.state);
                var error = networkInfoPopup.service.error || networkInfoPopup.service.lastConnectError;
                if (!error)
                    return state;
                // A state connman has since grown that _stateName does not
                // know is no reason to swallow the reason it failed.
                return state !== "" ? state + " (" + error + ")" : String(error);
            }
        }

        Flickable {
            id: infoFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: infoColumn.height
            flickableDirection: Flickable.AutoFlickIfNeeded
            clip: true

            // A connected network runs well past one screenful, and the
            // groups are clipped mid-row when it does - without this there
            // is nothing to say the rest is there.
            ScrollIndicator.vertical: ScrollIndicator { }

            Column {
                id: infoColumn
                width: infoFlickable.width
                spacing: Units.gu(2)

                Repeater {
                    model: networkInfoPopup.infoGroups
                    delegate: GroupBox {
                        id: infoGroupBox

                        // Held in a property of its own: inside the inner
                        // Repeater's delegate "modelData" is the row, and
                        // would shadow the group it came from.
                        readonly property var groupRows: modelData.groupRows

                        width: parent.width
                        title: modelData.groupTitle
                        visible: groupRows.length > 0

                        Column {
                            width: parent.width
                            Repeater {
                                model: infoGroupBox.groupRows
                                delegate: Column {
                                    width: parent.width

                                    HorizontalSeparator {
                                        width: parent.width
                                        visible: index > 0
                                    }
                                    LabelAndValue {
                                        width: parent.width
                                        label: modelData.rowLabel
                                        value: modelData.rowValue
                                    }
                                }
                            }
                        }
                    }
                }

                /*
                 * Only a network the device has stored has anything to decide:
                 * one it has never joined is not going to be auto-connected to
                 * and cannot be forgotten either.
                 */
                GroupBox {
                    width: parent.width
                    title: "Options"
                    visible: networkInfoPopup.forgettable

                    Column {
                        width: parent.width

                        LabelAndSwitch {
                            label: "Connect automatically"
                            checked: !!networkInfoPopup.service && networkInfoPopup.service.autoConnect
                            onToggled: networkInfoPopup.service.autoConnect = checked
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Units.gu(1)

            Button {
                Layout.fillWidth: true
                visible: networkInfoPopup.forgettable
                text: "Forget network"
                LuneOSButton.mainColor: LuneOSButton.negativeColor
                LuneOSButton.textColor: "white"
                // remove() drops the stored passphrase and disconnects, so
                // there is nothing left on this page to come back to.
                onClicked: {
                    networkInfoPopup.service.remove();
                    networkInfoPopup.close();
                }
            }
            Button {
                Layout.fillWidth: true
                text: "Done"
                LuneOSButton.mainColor: LuneOSButton.affirmativeColor
                onClicked: networkInfoPopup.close()
            }
        }
    }
}
