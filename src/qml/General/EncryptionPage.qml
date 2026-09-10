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
 * Encryption.
 *
 * Whether the data on a device can be read by anyone who picks it up was not
 * answerable from the UI, or from the bus at all. SFOS has an encryption
 * page, UBports has one under Security & Privacy, FuriOS has a Crypted panel.
 *
 * It reads com.palm.storage/volumes/getEncryptionStatus, added to storaged
 * for this. That looks at device-mapper's sysfs uuid for whatever block
 * device is under each mount: anything cryptsetup made says
 * CRYPT-LUKS2-<uuid>-<name>, which answers the question and says which of
 * LUKS1, LUKS2 or plain dm-crypt it is, without linking libcryptsetup into a
 * daemon that has no other use for it.
 *
 * This page reports and does not change. That is not a gap left for later -
 * it is what encryption is:
 *
 *  - Turning it on means writing a LUKS header over the start of the
 *    partition and re-encrypting everything behind it. Doing that in place,
 *    on a running system, to the filesystem the running system is on, is not
 *    something to offer behind a switch. SFOS sets encryption up during first
 *    boot and UBports at install for the same reason.
 *  - Changing the passphrase is safe in principle, but LuneOS has no device
 *    that ships encrypted for it to be useful on, and an untested key
 *    operation is how someone loses a partition.
 *
 * So it says what is true and where it would have to be done instead, which
 * is more use than a switch that could not work. cryptsetup is in the image,
 * so a device set up this way is understood and unlocked at boot; nothing
 * here has to be installed first.
 */
BasePage {
    id: pageRoot

    property bool serviceAvailable: false
    property var volumes: []

    readonly property bool anyEncrypted: {
        for (var i = 0; i < pageRoot.volumes.length; i++) {
            if (pageRoot.volumes[i].encrypted === true)
                return true;
        }
        return false;
    }

    Component.onCompleted: retrieveProperties();

    function volumeName(volume) {
        if (volume.mountPoint === "/")
            return "System";
        if (volume.mountPoint === "/media/internal")
            return "Internal storage";

        var parts = volume.mountPoint.split("/");
        var last = parts[parts.length - 1];
        return last !== "" ? last : volume.mountPoint;
    }

    function encryptionText(volume) {
        if (volume.encrypted !== true)
            return "Not encrypted";

        if (volume.encryptionType === "LUKS2" || volume.encryptionType === "LUKS1")
            return "Encrypted (" + volume.encryptionType + ")";
        if (volume.encryptionType === "PLAIN")
            return "Encrypted (plain dm-crypt)";
        return "Encrypted";
    }

    SettingsPageContent {
        ServiceUnavailableNotice {
            visible: !pageRoot.serviceAvailable
            serviceName: "com.palm.storage"
            description: "The storage daemon did not answer, so whether this " +
                         "device is encrypted cannot be read. A build older " +
                         "than the one that added volumes/getEncryptionStatus " +
                         "will not have it."
            onRetry: pageRoot.retrieveProperties()
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.serviceAvailable

            title: "Volumes"

            Column {
                width: parent.width

                Repeater {
                    model: pageRoot.volumes

                    delegate: Column {
                        width: parent.width

                        HorizontalSeparator {
                            width: parent.width
                            visible: index > 0
                            height: visible ? 1 : 0
                        }

                        LabelAndValue {
                            width: parent.width
                            label: pageRoot.volumeName(modelData)
                            value: pageRoot.encryptionText(modelData)
                        }
                    }
                }

                Label {
                    width: parent.width
                    visible: pageRoot.volumes.length === 0
                    height: visible ? Units.gu(6) : 0
                    verticalAlignment: Text.AlignVCenter
                    text: "No storage was reported."
                    color: "#666666"
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }
            }
        }

        ExplanationText {
            visible: pageRoot.serviceAvailable && pageRoot.anyEncrypted
            text: "What is on an encrypted volume cannot be read without the " +
                  "key, including by anyone who takes the storage out of the " +
                  "device. It is unlocked at boot and is readable normally " +
                  "from then until the device is switched off."
        }

        ExplanationText {
            visible: pageRoot.serviceAvailable && !pageRoot.anyEncrypted
            text: "Nothing on this device is encrypted. Anyone who can take " +
                  "the storage out can read what is on it, whatever screen " +
                  "lock is set."
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.serviceAvailable && !pageRoot.anyEncrypted

            title: "Turning it on"

            Column {
                width: parent.width

                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Encryption has to be set up when the device is " +
                          "flashed. Turning it on means writing a new header " +
                          "over the start of the partition and re-encrypting " +
                          "everything behind it, which is not something to do " +
                          "to a filesystem the device is currently running " +
                          "from - so it is not offered here, any more than it " +
                          "is on the systems that do ship encrypted."
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }
            }
        }

        GroupBox {
            width: parent.width

            Column {
                width: parent.width

                Button {
                    text: "Screen & Lock"
                    LuneOSButton.mainColor: LuneOSButton.secondaryColor
                    onClicked: pageRoot.openScreenLockSettings()
                }
            }
        }

        ExplanationText {
            text: "A screen lock keeps someone out of a device that is " +
                  "switched on. It is a different thing from encryption and " +
                  "worth having either way."
        }
    }

    /*
     * Bindings with storaged
     */
    function retrieveProperties() {
        luna.call("luna://com.palm.storage/volumes/getEncryptionStatus", "{}",
                  _handleEncryptionStatus, _handleServiceUnavailable);
    }

    function _handleEncryptionStatus(message) {
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
    function openScreenLockSettings() {
        luna.call("luna://com.webos.service.applicationManager/launch",
                  JSON.stringify({"id": "org.webosports.app.settings.screenlock"}),
                  _handleSetSuccess, _handleSetError);
    }
}
