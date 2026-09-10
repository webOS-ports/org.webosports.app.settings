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
 * Storage.
 *
 * webOS 3.0.5 put a single "Available Storage" line in Device Info and
 * nothing else, and that line is gone here too. SFOS has a storage page with
 * a usage ring, UBports puts one under About, GNOME under System.
 *
 * The figures come from com.palm.storage/volumes/getSpaceInfo, which was
 * added to storaged for this. Nothing on the bus could answer it before:
 * luna-prefs has storageCapacity and storageFreeSpace but each is one statfs
 * of /media/internal with no units, no device and no way to ask about the
 * root filesystem or a card, and com.webos.service.pdm knows only about
 * attached USB and SD devices. storaged already owns partitions on this
 * device - it mounts them for mass storage mode and erases them - so it is
 * where the question belongs.
 *
 * The reply is every mount backed by a real block device, which is both the
 * internal partitions and whatever card or stick is plugged in, so this page
 * does not have to ask two services and stitch their answers together. It
 * also means nothing here is specific to one device's partition layout: a
 * Halium port with a separate userdata partition and a mainline board with
 * everything on one filesystem both simply list what they have.
 *
 * There is no breakdown by what is using the space. That would mean walking
 * the tree, which is slow enough to need a progress indicator and a way to
 * stop it, and is worth doing on its own rather than bolted on here.
 */
BasePage {
    id: pageRoot

    property bool serviceAvailable: false
    property var volumes: []

    Component.onCompleted: retrieveProperties();

    /*
     * Powers of 1024 with the SI-ish names everything on a phone uses. Not
     * powers of 1000: the figure has to agree with what the same card reads
     * as on a computer, and every file manager that matters counts this way.
     */
    function formatBytes(bytes) {
        if (bytes === undefined || bytes === null)
            return "";

        var units = ["B", "KB", "MB", "GB", "TB"];
        var value = bytes;
        var unit = 0;

        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024;
            unit++;
        }

        // A whole number of bytes or kilobytes; one decimal above that, which
        // is where the difference between 1.2 and 1.9 GB starts to matter.
        return (unit <= 1 ? Math.round(value) : value.toFixed(1)) + " " + units[unit];
    }

    /*
     * A name for a mount point. The two that every device has are worth
     * naming properly; anything else is a card or a stick and is best called
     * whatever it is mounted as.
     */
    function volumeName(volume) {
        if (volume.mountPoint === "/")
            return "System";
        if (volume.mountPoint === "/media/internal")
            return "Internal storage";

        var parts = volume.mountPoint.split("/");
        var last = parts[parts.length - 1];
        return last !== "" ? last : volume.mountPoint;
    }

    function usedBytes(volume) {
        if (volume.sizeBytes === undefined || volume.availableBytes === undefined)
            return 0;
        // Against size minus available, not size minus free: the reserve a
        // filesystem keeps for root is not space anyone can use, so counting
        // it as free would show a device as emptier than it is.
        return volume.sizeBytes - volume.availableBytes;
    }

    function usedFraction(volume) {
        if (!volume.sizeBytes || volume.sizeBytes <= 0)
            return 0;
        return Math.max(0, Math.min(1, pageRoot.usedBytes(volume) / volume.sizeBytes));
    }

    SettingsPageContent {
        ServiceUnavailableNotice {
            visible: !pageRoot.serviceAvailable
            serviceName: "com.palm.storage"
            description: "The storage daemon did not answer, so how full this " +
                         "device is cannot be read. A build older than the one " +
                         "that added volumes/getSpaceInfo will not have it."
            onRetry: pageRoot.retrieveProperties()
        }

        Repeater {
            model: pageRoot.volumes

            delegate: Column {
                width: parent.width
                spacing: Units.gu(1)

                GroupBox {
                    width: parent.width
                    title: pageRoot.volumeName(modelData)

                    Column {
                        width: parent.width
                        spacing: Units.gu(1)

                        Item {
                            width: parent.width
                            height: Units.gu(3)

                            Rectangle {
                                anchors.fill: parent
                                radius: Units.gu(0.6)
                                color: "#ffffff"
                                border.color: "#9a9a9a"
                                border.width: 1
                            }

                            Rectangle {
                                x: 1
                                y: 1
                                height: parent.height - 2
                                width: pageRoot.usedFraction(modelData) * (parent.width - 2)
                                radius: Units.gu(0.5)
                                // Amber once there is little room left, red
                                // when there is almost none - the point at
                                // which an update or a photo starts failing.
                                color: pageRoot.usedFraction(modelData) > 0.95 ? "#be0003"
                                       : (pageRoot.usedFraction(modelData) > 0.85 ? "#d08b00"
                                                                                  : "#3f9c35")
                            }
                        }

                        LabelAndValue {
                            width: parent.width
                            label: "Used"
                            value: pageRoot.formatBytes(pageRoot.usedBytes(modelData)) +
                                   " of " + pageRoot.formatBytes(modelData.sizeBytes)
                        }

                        HorizontalSeparator {
                            width: parent.width
                        }

                        LabelAndValue {
                            width: parent.width
                            label: "Free"
                            value: pageRoot.formatBytes(modelData.availableBytes)
                        }

                        HorizontalSeparator {
                            width: parent.width
                        }

                        LabelAndValue {
                            width: parent.width
                            label: "Filesystem"
                            value: modelData.fsType +
                                   (modelData.readOnly ? ", read only" : "")
                        }

                        HorizontalSeparator {
                            width: parent.width
                        }

                        LabelAndValue {
                            width: parent.width
                            label: "Device"
                            value: modelData.device
                        }
                    }
                }
            }
        }

        Label {
            width: parent.width
            visible: pageRoot.serviceAvailable && pageRoot.volumes.length === 0
            height: visible ? Units.gu(6) : 0
            verticalAlignment: Text.AlignVCenter
            text: "No storage was reported."
            color: "#666666"
            font.pixelSize: FontUtils.sizeToPixels("medium")
        }

        ExplanationText {
            visible: pageRoot.serviceAvailable
            text: "Free is what is still usable. A filesystem keeps a little " +
                  "back that only the system may write to, so it is always a " +
                  "shade less than the arithmetic suggests."
        }

        GroupBox {
            width: parent.width

            Column {
                width: parent.width

                Button {
                    text: "Encryption"
                    LuneOSButton.mainColor: LuneOSButton.secondaryColor
                    onClicked: pageRoot.openEncryptionSettings()
                }
            }
        }
    }

    /*
     * Bindings with storaged
     */
    function retrieveProperties() {
        // No subscription: storaged is a dynamic service that exits about ten
        // seconds after the last question, and how full a device is does not
        // move fast enough to be worth keeping it alive for. Re-read on
        // Refresh, or by leaving and coming back.
        luna.call("luna://com.palm.storage/volumes/getSpaceInfo", "{}",
                  _handleSpaceInfo, _handleServiceUnavailable);
    }

    function _handleSpaceInfo(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue) {
            pageRoot.serviceAvailable = false;
            return;
        }

        pageRoot.volumes = response.volumes ? response.volumes : [];
        pageRoot.serviceAvailable = true;
    }

    function _handleServiceUnavailable(message) {
        console.warn("Storage daemon did not answer: " + message);
        pageRoot.serviceAvailable = false;
    }

    // Each settings category is its own launchable application on the device.
    function openEncryptionSettings() {
        luna.call("luna://com.webos.service.applicationManager/launch",
                  JSON.stringify({"id": "org.webosports.app.settings.encryption"}),
                  _handleSetSuccess, _handleSetError);
    }
}
