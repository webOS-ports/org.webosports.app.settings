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

import "../Common"

// Units & font sizes
import LunaNext.Common 0.1

BasePage {
    id: esimPageId

    // Mirrors com.webos.service.esim/getStatus
    property bool esimAvailable: false
    property int slotCount: 1
    property int activeSlot: 1
    // ofono only publishes ActiveCardSlot while a card is present, so on a
    // single-SIM device with the eUICC's slot inactive there is no card and no
    // active slot to report. Distinguish that from "slot 1 is active": with it
    // unknown, every slot is offered rather than one being disabled on a guess.
    property bool activeSlotKnown: false
    property bool simPresent: false
    property string iccid: ""

    // From getChipInfo - the EID identifies the chip itself, not a profile
    property string eid: ""
    property string freeSpace: ""

    property var profiles: []
    property bool busy: false
    property string statusText: ""

    // Progress of a download, fed by the downloadProfile subscription
    property string downloadStage: ""

    Component.onCompleted: {
        // SwipeView does not reliably start on the first page on its own, so
        // say so explicitly - the tab strip syncs the view from here
        esimTabBar.currentIndex = 0;
        esimTabBar._sync();
        subscribeStatus();
    }

    function subscribeStatus() {
        luna.subscribe("luna://com.webos.service.esim/getStatus",
                       JSON.stringify({"subscribe": true}),
                       onStatusChanged, _handleGetError);
    }

    function onStatusChanged(message) {
        var response = JSON.parse(message.payload);

        esimAvailable = response.available === true;
        slotCount = response.slotCount !== undefined ? response.slotCount : 1;
        activeSlotKnown = response.activeSlot !== undefined;
        activeSlot = activeSlotKnown ? response.activeSlot : 1;
        simPresent = response.simPresent === true;
        iccid = response.iccid !== undefined ? response.iccid : "";

        if (esimAvailable) {
            refreshChipInfo();
            refreshProfiles();
        }
    }

    function _handleGetError(message) {
        esimAvailable = false;
    }

    function refreshChipInfo() {
        luna.call("luna://com.webos.service.esim/getChipInfo", "{}",
                  function (message) {
                      var response = JSON.parse(message.payload);

                      if (!response.returnValue || !response.result)
                          return;

                      eid = response.result.eidValue !== undefined
                              ? response.result.eidValue : "";

                      if (response.result.EUICCInfo2 !== undefined &&
                          response.result.EUICCInfo2.extCardResource !== undefined) {
                          var free = response.result.EUICCInfo2
                                        .extCardResource.freeNonVolatileMemory;
                          freeSpace = Math.round(free / 1024) + " kB free";
                      }
                  },
                  function (message) { eid = ""; });
    }

    function refreshProfiles() {
        busy = true;
        luna.call("luna://com.webos.service.esim/getProfiles", "{}",
                  function (message) {
                      var response = JSON.parse(message.payload);

                      busy = false;
                      profiles = (response.returnValue && response.result)
                                   ? response.result : [];
                  },
                  function (message) {
                      busy = false;
                      profiles = [];
                      statusText = "Could not read the profile list";
                  });
    }

    function profileAction(method, iccidValue, extra) {
        var request = {"iccid": iccidValue};

        if (extra !== undefined) {
            for (var key in extra)
                request[key] = extra[key];
        }

        busy = true;
        statusText = "";

        luna.call("luna://com.webos.service.esim/" + method,
                  JSON.stringify(request),
                  function (message) {
                      var response = JSON.parse(message.payload);

                      busy = false;

                      if (!response.returnValue) {
                          statusText = response.errorText !== undefined
                                         ? response.errorText : "Failed";
                          return;
                      }

                      refreshProfiles();
                  },
                  function (message) {
                      busy = false;
                      statusText = "Failed: " + message.payload;
                  });
    }

    /*
     * lpac reports a failure as the name of the SGP.22 step that failed -
     * "es9p_authenticate_client" and the like - which says nothing to anyone
     * who has not read the specification. Each step fails for its own small
     * set of reasons, so name them.
     */
    function _downloadFailureText(response) {
        var step = response.errorText !== undefined ? response.errorText : "";
        var detail = response.errorDetail !== undefined
                        ? " (" + response.errorDetail + ")" : "";

        switch (step) {
        case "es9p_initiate_authentication":
            return "Could not reach the operator's server" + detail +
                   ". Check the SM-DP+ address, and that this device is " +
                   "online.";
        case "es9p_authenticate_client":
            return "The operator would not accept this activation code" +
                   detail + ". A code can normally be used only once, so " +
                   "check that it is the right one and has not already been " +
                   "added to another device.";
        case "es10b_authenticate_server":
            return "The eSIM chip rejected the operator's server" + detail +
                   ". The server's certificate is not one this chip trusts.";
        case "es9p_get_bound_profile_package":
            return "The operator has no profile waiting for this code" +
                   detail + ".";
        case "es10b_load_bound_profile_package":
            return "The eSIM chip refused the profile" + detail +
                   ". It may be out of space - delete a profile and try again.";
        case "":
            return "Download failed";
        default:
            return "Download failed at " + step + detail + ".";
        }
    }

    function downloadProfile(smdp, activationCode, confirmationCode) {
        var request = {"smdp": smdp, "activationCode": activationCode,
                       "subscribe": true};

        if (confirmationCode !== "")
            request["confirmationCode"] = confirmationCode;

        busy = true;
        statusText = "";
        downloadStage = "starting";

        luna.subscribe("luna://com.webos.service.esim/downloadProfile",
                       JSON.stringify(request),
                       function (message) {
                           var response = JSON.parse(message.payload);

                           // Progress updates carry a stage; the final reply
                           // does not
                           if (response.stage !== undefined) {
                               downloadStage = response.stage;
                               return;
                           }

                           busy = false;
                           downloadStage = "";

                           if (!response.returnValue) {
                               statusText = _downloadFailureText(response);
                               return;
                           }

                           statusText = "Profile downloaded";
                           refreshProfiles();
                       },
                       function (message) {
                           busy = false;
                           downloadStage = "";
                           statusText = "Download failed";
                       });
    }

    function setActiveSlot(slot) {
        busy = true;
        statusText = "";

        luna.call("luna://com.webos.service.esim/setActiveSlot",
                  JSON.stringify({"slot": slot}),
                  function (message) {
                      busy = false;
                  },
                  function (message) {
                      busy = false;
                      // Switching twice in quick succession fails while the
                      // card is still being re-read - say so rather than
                      // implying the hardware is broken
                      statusText = "Could not switch slot. Wait a few seconds " +
                                   "and try again.";
                  });
    }

    // --- QR scanning ------------------------------------------------------
    property bool scanning: false
    property string scanStatus: ""
    property bool cameraFailed: false

    // One grab is in flight at a time, and consecutive grabs alternate between
    // two files. Leaving the tab and coming back can leave a grab from the old
    // run still on its way to the service; with a single fixed path the new
    // run overwrites the file the old one is being decoded from, and the
    // decoder reads a half-written PNG ("No valid frames found").
    property bool scanBusy: false
    property int scanSeq: 0

    function startScan() {
        cameraFailed = false;
        scanStatus = "Point the camera at the QR code";
        scanning = true;
    }

    function stopScan() {
        scanning = false;
        scanStatus = "";
        scanBusy = false;
    }

    // Grabs the current preview frame and asks the service to decode it. One
    // frame at a time - a grab is only started once the previous answer is in,
    // so a slow decode cannot pile up requests.
    function grabAndDecode() {
        if (!scanning || scanBusy)
            return;

        if (!qrScannerLoaderId.item) {
            scanStatus = "The camera is not available";
            return;
        }

        scanBusy = true;
        scanSeq = (scanSeq + 1) % 2;

        var path = "/tmp/esim-qr-scan-" + scanSeq + ".png";

        function nextFrame() {
            esimPageId.scanBusy = false;

            if (esimPageId.scanning)
                qrScanTimerId.restart();
        }

        qrScannerLoaderId.item.grabFrame(path, function (ok) {
            if (!ok) {
                scanStatus = "Could not read from the camera";
                nextFrame();
                return;
            }

            luna.call("luna://com.webos.service.esim/scanQrCode",
                      JSON.stringify({"path": path}),
                      function (message) {
                          var response = JSON.parse(message.payload);

                          if (response.returnValue && response.smdp !== undefined) {
                              smdpField.text = response.smdp;
                              codeField.text = response.activationCode;
                              confirmField.text =
                                  response.confirmationCode !== undefined
                                      ? response.confirmationCode : "";
                              esimPageId.statusText =
                                  "Activation code read from the QR code";
                              esimPageId.scanBusy = false;

                              // Leaving the tab tears the camera down, and
                              // this is running on the service reply's own
                              // stack. Let that unwind first: stopping a
                              // GStreamer pipeline from inside a callback the
                              // pipeline's own machinery is still walking is
                              // how a preview turns into a dead application.
                              // Then straight to the form, so the user can
                              // check the code before spending a one-shot one.
                              Qt.callLater(function () {
                                  esimPageId.stopScan();
                                  esimTabBar.currentIndex = 1;
                              });

                              return;
                          }

                          if (response.returnValue) {
                              // Decoded something that is not an eSIM code
                              esimPageId.scanStatus =
                                  "That barcode is not an eSIM activation code";
                          }

                          nextFrame();
                      },
                      function (message) {
                          // A frame with no barcode in it is the normal case
                          // while the user is still aiming, so this is not
                          // worth putting on screen every 1.2 seconds.
                          nextFrame();
                      });
        });
    }

    Timer {
        id: qrScanTimerId
        interval: 1200
        repeat: false
        running: false
        onTriggered: esimPageId.grabAndDecode()
    }

    onScanningChanged: {
        if (scanning)
            qrScanTimerId.restart();
        else
            qrScanTimerId.stop();
    }

    // An activation code as printed on an operator's QR: LPA:1$server$code
    function applyLpaString(text) {
        var parts = text.split("$");

        if (parts.length < 3)
            return false;

        smdpField.text = parts[1];
        codeField.text = parts[2];

        if (parts.length > 3)
            confirmField.text = parts[3];

        return true;
    }

    /*
     * The webOS way of showing a handful of exclusive choices is the segmented
     * pill - a row of joined buttons where the selected one is filled in blue,
     * the same control the components gallery demonstrates under RadioButton.
     * A flat TabBar was easy to mistake for a heading; a pill visibly groups
     * the three and shows which of them you are on.
     *
     * Everything is kept in step by assignment rather than by bindings:
     * clicking a RadioButton assigns to its own "checked", which would destroy
     * any binding standing on that property, and the same goes for the
     * SwipeView's index once anything assigns a starting page.
     */
    Item {
        id: esimTabBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Units.gu(1)
        anchors.rightMargin: Units.gu(1)
        anchors.topMargin: Units.gu(0.5)
        height: Units.gu(4)

        property int currentIndex: 0

        function _sync() {
            for (var i = 0; i < esimTabRepeaterId.count; i++) {
                var tab = esimTabRepeaterId.itemAt(i);

                if (tab)
                    tab.checked = (i === esimTabBar.currentIndex);
            }

            esimTabView.currentIndex = esimTabBar.currentIndex;
        }

        onCurrentIndexChanged: _sync()
        Component.onCompleted: _sync()

        Row {
            anchors.fill: parent

            Repeater {
                id: esimTabRepeaterId
                model: ["Profiles", "Add profile", "Scan QR"]

                RadioButton {
                    // The pill's rounded ends and dividers come from
                    // Positioner.isFirstItem / isLastItem, so these have to sit
                    // directly in a Row for the style to know its own shape.
                    LuneOSRadioButton.useCollapsedLayout: true

                    width: Math.round(esimTabBar.width / esimTabRepeaterId.count)
                    height: esimTabBar.height

                    text: modelData
                    font.pixelSize: FontUtils.sizeToPixels("large")
                    font.weight: checked ? Font.Bold : Font.Normal

                    onClicked: esimTabBar.currentIndex = index
                }
            }
        }
    }

    SwipeView {
        id: esimTabView
        anchors.top: esimTabBar.bottom
        anchors.topMargin: Units.gu(0.5)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        onCurrentIndexChanged: esimTabBar.currentIndex = currentIndex

        // ---- the card and what is on it ----------------------------------
        ScrollView {
            id: esimProfilesScrollId
            clip: true

            // Without this the layout may grow wider than the viewport and the
            // page scrolls sideways, which it should never do
            contentWidth: availableWidth

            ColumnLayout {
                width: esimProfilesScrollId.availableWidth
                spacing: Units.gu(1)

                Label {
                    Layout.fillWidth: true
                    visible: !esimPageId.esimAvailable
                    wrapMode: Text.WordWrap
                    text: "No eUICC was found on this device. Either there is " +
                          "no eSIM chip, or the modem driver cannot open " +
                          "logical channels to it. An eSIM adapter card in the " +
                          "SIM slot works too."
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }

                GroupBox {
                    Layout.fillWidth: true
                    visible: esimPageId.esimAvailable
                    title: "Chip"

                    ColumnLayout {
                        width: parent.width
                        spacing: Units.gu(0.5)

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WrapAnywhere
                            text: "EID: " + (esimPageId.eid !== ""
                                             ? esimPageId.eid : "reading...")
                            font.pixelSize: FontUtils.sizeToPixels("small")
                        }

                        Label {
                            Layout.fillWidth: true
                            visible: esimPageId.freeSpace !== ""
                            text: esimPageId.freeSpace
                            font.pixelSize: FontUtils.sizeToPixels("small")
                        }

                        Label {
                            Layout.fillWidth: true
                            visible: esimPageId.iccid !== ""
                            wrapMode: Text.WrapAnywhere
                            text: "Active SIM: " + esimPageId.iccid
                            font.pixelSize: FontUtils.sizeToPixels("small")
                        }
                    }
                }

                // Only worth showing where the eUICC is one of several physical
                // slots and the modem can only use one at a time
                GroupBox {
                    Layout.fillWidth: true
                    visible: esimPageId.esimAvailable && esimPageId.slotCount > 1
                    title: "SIM slot"

                    ColumnLayout {
                        width: parent.width
                        spacing: Units.gu(0.5)

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: esimPageId.activeSlotKnown
                                  ? "Slot " + esimPageId.activeSlot + " of " +
                                    esimPageId.slotCount + " is in use. The " +
                                    "eSIM is only reachable while its slot is " +
                                    "active."
                                  : "No SIM slot is active, so the eSIM cannot " +
                                    "be read. Select the slot the eSIM is in " +
                                    "(usually the last one)."
                            font.pixelSize: FontUtils.sizeToPixels("small")
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Units.gu(1)

                            Repeater {
                                model: esimPageId.slotCount

                                Button {
                                    text: "Slot " + (index + 1)
                                    enabled: !esimPageId.busy &&
                                             (!esimPageId.activeSlotKnown ||
                                              esimPageId.activeSlot !== (index + 1))
                                    onClicked: esimPageId.setActiveSlot(index + 1)
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }
                }

                GroupBox {
                    Layout.fillWidth: true
                    visible: esimPageId.esimAvailable
                    title: "Profiles"

                    ColumnLayout {
                        width: parent.width
                        spacing: Units.gu(0.5)

                        Label {
                            Layout.fillWidth: true
                            visible: esimPageId.profiles.length === 0 &&
                                     !esimPageId.busy
                            text: "No profiles installed."
                            font.pixelSize: FontUtils.sizeToPixels("medium")
                        }

                        Repeater {
                            model: esimPageId.profiles

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Units.gu(0.2)

                                Label {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: (modelData.profileNickname
                                            ? modelData.profileNickname
                                            : (modelData.profileName
                                                ? modelData.profileName
                                                : modelData.iccid))
                                    font.pixelSize: FontUtils.sizeToPixels("medium")
                                }

                                Label {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WrapAnywhere
                                    text: (modelData.serviceProviderName
                                            ? modelData.serviceProviderName + " - " : "") +
                                          modelData.iccid + " - " +
                                          modelData.profileState
                                    font.pixelSize: FontUtils.sizeToPixels("small")
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Units.gu(0.5)

                                    Button {
                                        text: modelData.profileState === "enabled"
                                                ? "Disable" : "Enable"
                                        enabled: !esimPageId.busy
                                        onClicked: esimPageId.profileAction(
                                            modelData.profileState === "enabled"
                                                ? "disableProfile" : "enableProfile",
                                            modelData.iccid)
                                    }

                                    Button {
                                        text: "Delete"
                                        // A deleted profile is gone: most can
                                        // only be installed once
                                        enabled: !esimPageId.busy &&
                                                 modelData.profileState !== "enabled"
                                        onClicked: esimPageId.profileAction(
                                            "deleteProfile", modelData.iccid)
                                    }

                                    Item { Layout.fillWidth: true }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: "#40808080"
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Button {
                                text: "Refresh"
                                enabled: !esimPageId.busy
                                onClicked: {
                                    esimPageId.refreshChipInfo();
                                    esimPageId.refreshProfiles();
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: esimPageId.statusText !== ""
                    wrapMode: Text.WordWrap
                    text: esimPageId.statusText
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }
            }
        }

        // ---- adding one --------------------------------------------------
        ScrollView {
            id: esimAddScrollId
            clip: true

            contentWidth: availableWidth

            ColumnLayout {
                width: esimAddScrollId.availableWidth
                spacing: Units.gu(1)

                Label {
                    Layout.fillWidth: true
                    visible: !esimPageId.esimAvailable
                    wrapMode: Text.WordWrap
                    text: "No eUICC was found on this device, so there is " +
                          "nothing to install a profile onto."
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }

                GroupBox {
                    Layout.fillWidth: true
                    visible: esimPageId.esimAvailable
                    title: "Add a profile"

                    ColumnLayout {
                        width: parent.width
                        spacing: Units.gu(0.5)

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: "From your operator's manual install details, " +
                                  "or paste the whole LPA:1$... string from " +
                                  "their QR code into the address field."
                            font.pixelSize: FontUtils.sizeToPixels("small")
                        }

                        TextField {
                            id: smdpField
                            Layout.fillWidth: true
                            placeholderText: "SM-DP+ address"
                            font.pixelSize: FontUtils.sizeToPixels("medium")

                            // Paste the QR contents here and it splits itself up
                            onTextChanged: {
                                if (text.indexOf("$") >= 0)
                                    esimPageId.applyLpaString(text);
                            }
                        }

                        TextField {
                            id: codeField
                            Layout.fillWidth: true
                            placeholderText: "Activation code"
                            font.pixelSize: FontUtils.sizeToPixels("medium")
                        }

                        TextField {
                            id: confirmField
                            Layout.fillWidth: true
                            placeholderText: "Confirmation code (optional)"
                            font.pixelSize: FontUtils.sizeToPixels("medium")
                        }

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            visible: esimPageId.downloadStage !== ""
                            text: "Downloading: " + esimPageId.downloadStage
                            font.pixelSize: FontUtils.sizeToPixels("small")
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Button {
                                text: "Download profile"
                                enabled: !esimPageId.busy && smdpField.text !== "" &&
                                         codeField.text !== ""
                                onClicked: esimPageId.downloadProfile(smdpField.text,
                                                codeField.text, confirmField.text)
                            }

                            Item { Layout.fillWidth: true }
                        }

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: "Downloading needs a working internet " +
                                  "connection, and an activation code can " +
                                  "normally only be used once."
                            font.pixelSize: FontUtils.sizeToPixels("small")
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: esimPageId.statusText !== ""
                    wrapMode: Text.WordWrap
                    text: esimPageId.statusText
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }
            }
        }

        // ---- scanning the operator's QR ----------------------------------
        Item {
            id: esimScanTab

            // Only hold the camera open while this tab is actually showing
            property bool active: esimTabView.currentIndex === 2

            onActiveChanged: {
                if (active)
                    esimPageId.startScan();
                else
                    esimPageId.stopScan();
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Units.gu(1)
                spacing: Units.gu(1)

                // The camera lives in its own file so that a missing
                // QtMultimedia, or any type in there failing to resolve,
                // cannot stop the other two tabs from loading
                Loader {
                    id: qrScannerLoaderId
                    Layout.fillWidth: true
                    // An empty Loader still claims the whole tab, which would
                    // push the explanation below it off the bottom of the
                    // screen - exactly when that explanation is the only thing
                    // left to show.
                    Layout.fillHeight: !esimPageId.cameraFailed
                    visible: !esimPageId.cameraFailed

                    source: "EsimQrScanner.qml"

                    onStatusChanged: {
                        if (status === Loader.Error) {
                            esimPageId.cameraFailed = true;
                            esimPageId.scanStatus =
                                "The camera components are not available";
                        }
                    }

                    onLoaded: {
                        item.active = Qt.binding(function () {
                            return esimScanTab.active;
                        });
                        item.cameraFailed.connect(function (message) {
                            esimPageId.cameraFailed = true;
                            esimPageId.scanStatus = message;
                        });
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: esimPageId.cameraFailed
                    wrapMode: Text.WordWrap
                    text: "The camera could not be opened. You can still type " +
                          "the SM-DP+ address and activation code on the Add " +
                          "profile tab, or paste the whole LPA:1$... string " +
                          "into the address field there."
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }

                Label {
                    Layout.fillWidth: true
                    visible: esimPageId.scanStatus !== ""
                    wrapMode: Text.WordWrap
                    text: esimPageId.scanStatus
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }
            }
        }
    }
}
