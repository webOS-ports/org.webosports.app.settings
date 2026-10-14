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
import LuneOS.Forms 1.0

BasePage {

    property alias deviceName:        deviceNameLabel.value
    property alias deviceSerial:      deviceSerialLabel.value
    property alias deviceMACAddress:  deviceMACAddrLabel.value

    property alias softwareVersion:        softwareVersionLabel.value
    property alias softwareCodename:       softwareCodenameLabel.value
    property alias softwareBuildTree:      softwareBuildTreeLabel.value
    property alias softwareBuildNumber:    softwareBuildNumberLabel.value
    property alias softwareKernelVersion:  softwareKernelVersionLabel.value
    property alias softwareAndroidVersion: softwareAndroidVersionLabel.value
    property alias softwareAndroidVendor:  softwareAndroidVendorLabel.value

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
                        id: softwareKernelVersionLabel
                        width: parent.width
                        label: "Kernel"
                    }

                    /* Only on a Halium device. A mainline device or the
                       emulator has no Android underneath, and a row there
                       saying so told nobody anything. */
                    HorizontalSeparator {
                        width: parent.width
                        visible: softwareAndroidVersionLabel.visible
                    }
                    LabelAndValue {
                        id: softwareAndroidVersionLabel
                        width: parent.width
                        visible: value !== ""
                        label: "Android Version"
                    }
                    /* The vendor partition - the HALs - can be a different
                       Android release from the system image LuneOS runs on
                       (the Q25: a 16 system on a 12 vendor), and it is the
                       vendor's that decides what the device can do. Hidden
                       where the image predates that split and has no vendor
                       release to report. */
                    HorizontalSeparator {
                        width: parent.width
                        visible: softwareAndroidVendorLabel.visible
                    }
                    LabelAndValue {
                        id: softwareAndroidVendorLabel
                        width: parent.width
                        visible: value !== ""
                        label: "Android Vendor"
                    }
                }
            }
        }
    }

    function retrieveProperties() {
        luna.call("luna://org.webosports.service.update/retrieveVersion", '{}', _handleRetrieveVersion, _handleGetError);
        luna.call("luna://com.android.properties/getProperty",
                  JSON.stringify({"keys": ["ro.serialno", "ro.product.model", "ro.product.manufacturer",
                                           "ro.build.version.release", "ro.build.version.sdk",
                                           "ro.vendor.build.version.release", "ro.vndk.version"]}),
                  _handleGetProperty, _handleGetError);
        luna.call("luna://com.webos.service.systemservice/osInfo/query",
                  JSON.stringify({"parameters": ["core_os_kernel_version"]}),
                  _handleOsInfo, _handleGetError);
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

    /* Joins a release and the API level it goes with: "16 (API 36)". Either
       half can be missing on an old or a stripped-down image. */
    function _androidRelease(release, level, levelName) {
        if (!release)
            return "";
        return level ? release + " (" + levelName + " " + level + ")" : release;
    }

    function _handleGetProperty(message) {
        if(message && message.payload) {
            var payloadValue = JSON.parse(message.payload);
            if(!payloadValue.returnValue) {
                // No Android underneath: a mainline device or the emulator.
                // The Android rows stay hidden.
                console.log("com.android.properties doesn't exist, we're probably in an emulator or using a device with mainline kernel");
            }
            else {
                // One object per property, each holding just that key. A
                // property the device does not set comes back empty.
                var props = {};
                for (var n = 0; n < payloadValue.properties.length; n++) {
                    var property = payloadValue.properties[n];
                    for (var key in property)
                        props[key] = property[key];
                }

                if (props["ro.serialno"])
                    deviceSerial = props["ro.serialno"];

                softwareAndroidVersion = _androidRelease(props["ro.build.version.release"],
                                                         props["ro.build.version.sdk"], "API");
                // ro.vndk.version rather than ro.vendor.build.version.sdk:
                // the VNDK is the interface the system image is held to.
                // On the Q25 the two agree (31).
                softwareAndroidVendor = _androidRelease(props["ro.vendor.build.version.release"],
                                                        props["ro.vndk.version"], "VNDK");

                var model = props["ro.product.model"] || "";
                var manufacturer = props["ro.product.manufacturer"] || "";
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

    function _handleOsInfo(message) {
        if(message && message.payload) {
            var payloadValue = JSON.parse(message.payload);
            if (payloadValue.core_os_kernel_version)
                softwareKernelVersion = payloadValue.core_os_kernel_version;
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
