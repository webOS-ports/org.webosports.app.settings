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

    Component.onCompleted: {
        retrieveProperties();
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
        luna.call("luna://com.palm.preferences/systemProperties/getSomeSysProperties", '[{"key":"com.palm.properties.nduid"}, {"key":"com.palm.properties.buildName"}, {"key":"com.palm.properties.buildNumber"}, {"key":"com.palm.properties.machineName"}, {"key":"com.palm.properties.browserOsName"}, {"key":"com.palm.properties.version"}]', _handleGetProperties, _handleGetError );
    }

    function _handleRetrieveVersion(message) {
        if(message && message.payload) {
            var payloadValue = JSON.parse(message.payload);

            if (payloadValue.localVersion) {
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
                deviceName = manufacturer + " " + model;
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
                else if (property["com.palm.properties.machineName"] && !deviceName) {
                    deviceName = property["com.palm.properties.machineName"];
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
