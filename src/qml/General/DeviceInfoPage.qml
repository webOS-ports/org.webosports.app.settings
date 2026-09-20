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
// Units & font sizes
import LunaNext.Common 0.1

import "../Common"

BasePage {

    property alias deviceName:        deviceNameLabel.value
    property alias deviceSerial:      deviceSerialLabel.value
    property alias deviceMACAddress:  deviceMACAddrLabel.value

    property alias softwareVersion:        softwareVersionLabel.value
    property alias softwareCodename:       softwareCodenameLabel.value
    property alias softwareBuildTree:      softwareBuildTreeLabel.value
    property alias softwareBuildNumber:    softwareBuildNumberLabel.value
    property alias softwareAndroidVersion: softwareAndroidVersionLabel.value

    /* Candidates for the device name, best first. The two service calls that
       supply them are asynchronous and either can answer first, so collect them
       and let _updateDeviceName() apply the precedence, rather than letting
       arrival order decide it as it used to.

       com.palm.properties.deviceName is the real answer: luneos-device-config's
       90-prefs-properties generator writes it at boot - from the adaptation's
       deviceinfo_name where there is one, otherwise from the same Android
       properties read below, or from the device tree's model on a mainline
       device. machineName is the Yocto MACHINE and only a last resort; it is
       what made this field read "pinephonepro". */
    property string _nameFromPrefs:   ""
    property string _nameFromAndroid: ""
    property string _nameFromMachine: ""

    /* What luna-prefs-data bakes into /etc/prefs/properties/deviceName when
       nothing overrides it. Seeing it means the generator did not run, and the
       Android properties are then a better answer than the placeholder. */
    readonly property string _unconfiguredName: "LuneOS Device"

    Component.onCompleted: {
        retrieveProperties();
    }

    function _updateDeviceName() {
        if (_nameFromPrefs && _nameFromPrefs !== _unconfiguredName)
            deviceName = _nameFromPrefs;
        else if (_nameFromAndroid)
            deviceName = _nameFromAndroid;
        else if (_nameFromPrefs)
            deviceName = _nameFromPrefs;
        else if (_nameFromMachine)
            deviceName = _nameFromMachine;
    }

    /* A settings page has a vertical layout: put everything in a Column */
    Flickable {
        id: flickableItem
        anchors.fill: parent
        anchors.margins: Units.gu(1)
        contentWidth: width
        contentHeight: contentItem.childrenRect.height
        flickableDirection: Flickable.AutoFlickIfNeeded
        clip: true

        Column {
            width: flickableItem.width
            spacing: Units.gu(2)

            GroupBox {
                width: parent.width

                title: "Device"
                Column {
                    width: parent.width

                    LabelAndValue {
                        id: deviceNameLabel
                        width: parent.width
                        label: "Name"
                    }
                    HorizontalSeparator {
                        width: parent.width
                    }
                    LabelAndValue {
                        id: deviceSerialLabel
                        width: parent.width
                        label: "Serial number"
                    }
                    HorizontalSeparator {
                        width: parent.width
                    }
                    LabelAndValue {
                        id: deviceMACAddrLabel
                        width: parent.width
                        label: "Wi-Fi MAC Address"
                    }
                }
            }

            GroupBox {
                width: parent.width

                title: "Software"
                Column {
                    width: parent.width

                    LabelAndValue {
                        id: softwareVersionLabel
                        width: parent.width
                        label: "Version"
                    }
                    HorizontalSeparator {
                        width: parent.width
                    }
                    LabelAndValue {
                        id: softwareCodenameLabel
                        width: parent.width
                        label: "Codename"
                    }
                    HorizontalSeparator {
                        width: parent.width
                    }
                    LabelAndValue {
                        id: softwareBuildTreeLabel
                        width: parent.width
                        label: "Build Tree"
                    }
                    HorizontalSeparator {
                        width: parent.width
                    }
                    LabelAndValue {
                        id: softwareBuildNumberLabel
                        width: parent.width
                        label: "Build Number"
                    }
                    HorizontalSeparator {
                        width: parent.width
                    }
                    LabelAndValue {
                        id: softwareAndroidVersionLabel
                        width: parent.width
                        label: "Android Version"
                    }
                }
            }
        }
    }

    function retrieveProperties() {
        luna.call("luna://org.webosports.service.update/retrieveVersion", '{}', _handleRetrieveVersion, _handleGetError);
        luna.call("luna://com.android.properties/getProperty",
                  '{"keys":["ro.serialno","ro.product.model","ro.product.manufacturer","ro.build.version.release"]}',
                  _handleGetProperty, _handleGetError);
        luna.call("luna://com.palm.connectionmanager/getinfo", '{}', _handleGetInfo, _handleGetError);
        luna.call("luna://com.palm.preferences/systemProperties/getSomeSysProperties", '[{"key":"com.palm.properties.nduid"}, {"key":"com.palm.properties.buildName"}, {"key":"com.palm.properties.buildNumber"}, {"key":"com.palm.properties.deviceName"}, {"key":"com.palm.properties.machineName"}, {"key":"com.palm.properties.browserOsName"}, {"key":"com.palm.properties.version"}]', _handleGetProperties, _handleGetError );
    }

    function _handleRetrieveVersion(message) {
        if(message && message.payload) {
            var payloadValue = JSON.parse(message.payload);

            if (typeof payloadValue.localVersion !== "undefined") {
                softwareVersion = payloadValue.localVersion;
            }
            if (payloadValue.codename) {
                softwareCodename = payloadValue.codename;
            }
            if (payloadValue.buildTree) {
                softwareBuildTree = payloadValue.buildTree;
            }
            if (payloadValue.buildNumber) {
                softwareBuildNumber = payloadValue.buildNumber;
            }
        }
    }

    function _handleGetProperty(message) {
        if(message && message.payload) {
            var payloadValue = JSON.parse(message.payload);
            if(!payloadValue.returnValue) {
                console.log("com.android.properties doesn't exist, we're probably in an emulator or using a device with mainline kernel");
                softwareAndroidVersion = "N/A; Not based on Android";
            }
            else {
                var model = "";
                var manufacturer = "";

                for (var n = 0; n < payloadValue.properties.length; n++) {
                    var property = payloadValue.properties[n];
                    if (property["ro.serialno"]) {
                        deviceSerial = property["ro.serialno"];
                    }
                    else if (property["ro.product.model"]) {
                        model = property["ro.product.model"];
                    }
                    else if (property["ro.product.manufacturer"]) {
                        manufacturer = property["ro.product.manufacturer"];
                    }
                    else if (property["ro.build.version.release"]) {
                        softwareAndroidVersion = property["ro.build.version.release"];
                    }
                }
                if (model) {
                    /* Some vendors already put the brand in the model, so
                       concatenating unconditionally gave "Google Google Pixel
                       6a". The generator applies the same rule. */
                    _nameFromAndroid = (manufacturer && model.indexOf(manufacturer) !== 0)
                                     ? manufacturer + " " + model
                                     : model;
                    _updateDeviceName();
                }
            }
        }
    }

    function _handleGetProperties(message) {
        if(message && message.payload) {
            var payloadValue = JSON.parse(message.payload);
            
            for (var n = 0; n < payloadValue.length; n++) {
                var property = payloadValue[n];
                if (property["com.palm.properties.nduid"] && !deviceSerial) {
                    deviceSerial = property["com.palm.properties.nduid"];
                }
                else if (property["com.palm.properties.buildName"] && !softwareBuildTree) {
                    softwareBuildTree = property["com.palm.properties.buildName"];
                }
                else if (property["com.palm.properties.deviceName"]) {
                    _nameFromPrefs = property["com.palm.properties.deviceName"];
                    _updateDeviceName();
                }
                else if (property["com.palm.properties.machineName"]) {
                    _nameFromMachine = property["com.palm.properties.machineName"];
                    _updateDeviceName();
                }
            }
        }
    }

    function _handleGetInfo(message) {
        if(message && message.payload) {
            var payloadValue = JSON.parse(message.payload);

            if (payloadValue.wifiInfo && payloadValue.wifiInfo.macAddress) {
                deviceMACAddress = payloadValue.wifiInfo.macAddress;
                deviceMACAddrLabel.label = "Wi-Fi MAC Address";
            } else if (payloadValue.wiredInfo && payloadValue.wiredInfo.macAddress) {
                deviceMACAddress = payloadValue.wiredInfo.macAddress;
                deviceMACAddrLabel.label = "MAC Address";
            }
        }
    }
}
