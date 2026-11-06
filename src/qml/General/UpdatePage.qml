/*
 * (c) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * Follows the Enyo Settings app's source/views/SystemUpdates.js (2014-2016,
 * Achim Königs, P. Douglas Reeder, Herman van Hazendonk).
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
import LuneOS.Forms 1.0
import LuneOS.System 1.0

/*
 * System Updates.
 *
 * The page the Enyo Settings app had as SystemUpdates.js, which this follows
 * step for step: check, then download, then install, one button at a time,
 * with the changes since the installed version listed under the status. The
 * QML app had only a placeholder of fake settings here. It talks to
 * org.webosports.service.update:
 *
 *  - checkUpdate reads the feed's manifest for this device's update channel
 *    and answers needUpdate with changesSinceLast, newest first. It also
 *    keeps what it found, which downloadUpdate needs. The Enyo page waited
 *    for "Check for updates"; this one checks when it opens, because the
 *    service's toast ("System update available") opens it and the user came
 *    here for the update.
 *  - downloadUpdate is a subscription: {percentage} while the image comes
 *    in, then {finished} or {error, msg, needCheck}. needCheck means what
 *    checkUpdate kept no longer matches the feed, so the page offers the
 *    check again rather than a retry.
 *  - initiateUpdate marks the next boot as a system update and restarts the
 *    device, which the page says above the button that does it.
 *
 * The service also checks after every boot and every 12 hours, so this page
 * is not the only way an update is found; it is where one is acted on.
 */
BasePage {
    id: pageRoot

    readonly property string updateService: "org.webosports.service.update"

    property bool serviceAvailable: true

    // "checking", "uptodate", "available", "downloading", "downloaded",
    // "installing", "restarting" or "failed". Not "state": that is Item's.
    property string updateState: "checking"
    // After "failed": the step to offer again ("check", "download", "install").
    property string failedStep: ""
    property string statusText: ""
    property var changes: []
    property real percentage: 0

    property string localVersion: ""
    property string codename: ""
    property string buildTree: ""
    property string buildNumber: ""

    property var _downloadCall: null

    readonly property bool busy: updateState === "checking" || updateState === "downloading" ||
                                 updateState === "installing" || updateState === "restarting"

    readonly property bool showCheck: updateState === "uptodate" ||
                                      (updateState === "failed" && failedStep === "check")
    readonly property bool showDownload: updateState === "available" ||
                                         (updateState === "failed" && failedStep === "download")
    readonly property bool showInstall: updateState === "downloaded" ||
                                        (updateState === "failed" && failedStep === "install")

    Component.onCompleted: {
        retrieveVersion();
        checkForUpdate();
    }

    Component.onDestruction: _endDownload()

    // A service that starts after the page opened, or comes back after a
    // crash, is asked again without "Try again".
    ServiceStatus {
        id: serviceStatus

        property bool wentAway: false

        serviceName: pageRoot.updateService
        onKnownChanged: if (known && !available) wentAway = true
        onAvailableChanged: {
            if (!available) {
                wentAway = true;
            } else if (wentAway) {
                wentAway = false;
                pageRoot.serviceAvailable = true;
                pageRoot.retrieveVersion();
                if (!pageRoot.busy)
                    pageRoot.checkForUpdate();
            }
        }
    }

    function versionText() {
        if (localVersion === "")
            return "Unknown";
        return codename !== "" ? localVersion + " (" + codename + ")" : localVersion;
    }

    SettingsPageContent {
        ServiceUnavailableNotice {
            visible: !pageRoot.serviceAvailable
            serviceName: pageRoot.updateService
            description: "The update service did not answer, so updates " +
                         "cannot be checked for or installed."
            onRetry: {
                pageRoot.serviceAvailable = true;
                pageRoot.retrieveVersion();
                pageRoot.checkForUpdate();
            }
        }

        GroupBox {
            width: parent.width

            title: "This device"

            Column {
                width: parent.width

                LabelAndValue {
                    objectName: "versionRow"
                    width: parent.width
                    label: "Version"
                    value: pageRoot.versionText()
                }
                HorizontalSeparator {
                    width: parent.width
                    visible: pageRoot.buildTree !== ""
                    height: visible ? 1 : 0
                }
                LabelAndValue {
                    objectName: "channelRow"
                    width: parent.width
                    visible: pageRoot.buildTree !== ""
                    height: visible ? implicitHeight : 0
                    label: "Update channel"
                    value: pageRoot.buildTree
                }
                HorizontalSeparator {
                    width: parent.width
                    visible: pageRoot.buildNumber !== ""
                    height: visible ? 1 : 0
                }
                LabelAndValue {
                    objectName: "buildRow"
                    width: parent.width
                    visible: pageRoot.buildNumber !== ""
                    height: visible ? implicitHeight : 0
                    label: "Build"
                    value: pageRoot.buildNumber
                }
            }
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.serviceAvailable

            title: "System update"

            Column {
                width: parent.width
                spacing: Units.gu(1)

                Row {
                    width: parent.width
                    spacing: Units.gu(1)

                    BusyIndicator {
                        id: busyIndicator
                        objectName: "updateBusyIndicator"
                        visible: pageRoot.busy && pageRoot.updateState !== "downloading"
                        running: visible
                        width: visible ? Units.gu(4) : 0
                        height: Units.gu(4)
                    }

                    Label {
                        objectName: "updateStatus"
                        width: parent.width - busyIndicator.width - (busyIndicator.visible ? parent.spacing : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        wrapMode: Text.WordWrap
                        text: pageRoot.statusText
                        font.pixelSize: FontUtils.sizeToPixels("medium")
                    }
                }

                ProgressBar {
                    objectName: "updateProgress"
                    width: parent.width
                    visible: pageRoot.updateState === "downloading"
                    from: 0
                    to: 100
                    value: pageRoot.percentage
                }

                Button {
                    objectName: "checkButton"
                    visible: pageRoot.showCheck
                    enabled: !pageRoot.busy
                    text: "Check for updates"
                    onClicked: pageRoot.checkForUpdate()
                }

                Button {
                    objectName: "downloadButton"
                    visible: pageRoot.showDownload
                    enabled: !pageRoot.busy
                    text: pageRoot.updateState === "failed" ? "Try the download again" : "Download update"
                    LuneOSButton.mainColor: LuneOSButton.affirmativeColor
                    onClicked: pageRoot.downloadUpdate()
                }

                Button {
                    objectName: "installButton"
                    visible: pageRoot.showInstall
                    enabled: !pageRoot.busy
                    text: "Install and restart"
                    LuneOSButton.mainColor: LuneOSButton.affirmativeColor
                    onClicked: pageRoot.installUpdate()
                }
            }
        }

        ExplanationText {
            visible: pageRoot.showInstall
            text: "The device restarts to install the update, and cannot be " +
                  "used until it has finished."
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.changes.length > 0

            title: "What is new"

            Column {
                width: parent.width
                spacing: Units.gu(1)

                Repeater {
                    model: pageRoot.changes

                    delegate: Column {
                        width: parent.width
                        spacing: Units.gu(0.5)

                        HorizontalSeparator {
                            width: parent.width
                            visible: index > 0
                            height: visible ? 1 : 0
                        }

                        Label {
                            width: parent.width
                            text: "Version " + modelData.version
                            font.weight: Font.Bold
                            font.pixelSize: FontUtils.sizeToPixels("medium")
                        }

                        Repeater {
                            model: modelData.changes ? modelData.changes : []

                            delegate: Label {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                // The manifest's words, never markup from the feed.
                                textFormat: Text.PlainText
                                text: "• " + modelData
                                font.pixelSize: FontUtils.sizeToPixels("medium")
                            }
                        }
                    }
                }
            }
        }

        ExplanationText {
            text: "The device also checks by itself after it starts and every " +
                  "12 hours, and shows a notification when an update is available."
        }
    }

    /*
     * Bindings with org.webosports.service.update
     */
    function _parse(message) {
        if (!message || !message.payload)
            return null;
        try {
            return JSON.parse(message.payload);
        } catch (e) {
            console.warn("Update service sent what is not JSON: " + message.payload);
            return null;
        }
    }

    function _fail(step, text) {
        failedStep = step;
        updateState = "failed";
        statusText = text;
    }

    function _serviceMissing(message) {
        console.warn("Update service did not answer: " + message);
        serviceAvailable = false;
    }

    function retrieveVersion() {
        luna.call("luna://" + updateService + "/retrieveVersion", "{}",
                  _handleRetrieveVersion, _handleGetError);
    }

    function _handleRetrieveVersion(message) {
        var r = _parse(message);
        if (!r || r.returnValue !== true)
            return;
        localVersion = r.localVersion !== undefined ? String(r.localVersion) : "";
        codename = r.codename ? r.codename : "";
        buildTree = r.buildTree ? r.buildTree : "";
        buildNumber = r.buildNumber ? r.buildNumber : "";
    }

    function checkForUpdate() {
        updateState = "checking";
        failedStep = "";
        changes = [];
        statusText = "Checking for updates…";
        luna.call("luna://" + updateService + "/checkUpdate", "{}",
                  _handleCheckUpdate, _handleCheckError);
    }

    function _handleCheckUpdate(message) {
        var r = _parse(message);
        if (!r) {
            _fail("check", "Could not check for updates: the update service gave no answer.");
            return;
        }
        if (r.returnValue === false || r.success !== true) {
            _fail("check", "Could not check for updates: " +
                  (r.message || r.errorText || "no reason was given."));
            return;
        }
        if (r.needUpdate === true) {
            changes = r.changesSinceLast ? r.changesSinceLast : [];
            updateState = "available";
            statusText = "An update is available.";
        } else {
            updateState = "uptodate";
            statusText = "This device is up to date.";
        }
    }

    function _handleCheckError(message) {
        _serviceMissing(message);
        _fail("check", "Could not check for updates.");
    }

    function downloadUpdate() {
        _endDownload();
        updateState = "downloading";
        failedStep = "";
        percentage = 0;
        statusText = "Downloading the update…";
        _downloadCall = luna.subscribe("luna://" + updateService + "/downloadUpdate",
                                       JSON.stringify({"subscribe": true}),
                                       _handleDownload, _handleDownloadError);
    }

    function _handleDownload(message) {
        var r = _parse(message);
        if (!r)
            return;

        if (r.error === true || r.returnValue === false) {
            _endDownload();
            var text = r.msg || r.errorText || "no reason was given.";
            if (r.needCheck === true) {
                // What the last check kept is no longer in the feed.
                _fail("check", text);
            } else {
                _fail("download", "The download failed: " + text);
            }
            return;
        }

        if (r.finished === true) {
            _endDownload();
            updateState = "downloaded";
            percentage = 100;
            statusText = "The update is downloaded and ready to install.";
            return;
        }

        if (r.percentage !== undefined) {
            var p = parseFloat(r.percentage);
            if (!isNaN(p)) {
                percentage = p;
                statusText = "Downloading the update: " + Math.floor(p) + "%";
            }
        }
    }

    function _handleDownloadError(message) {
        _endDownload();
        _serviceMissing(message);
        _fail("download", "The download failed.");
    }

    function _endDownload() {
        if (_downloadCall) {
            _downloadCall.cancel();
            _downloadCall = null;
        }
    }

    function installUpdate() {
        updateState = "installing";
        failedStep = "";
        statusText = "Preparing to install…";
        luna.call("luna://" + updateService + "/initiateUpdate", "{}",
                  _handleInitiateUpdate, _handleInitiateError);
    }

    function _handleInitiateUpdate(message) {
        var r = _parse(message);
        if (r && r.success === true) {
            updateState = "restarting";
            statusText = "Restarting to install the update…";
            return;
        }
        _fail("install", "The update could not be started: " +
              ((r && (r.msg || r.errorText)) || "no reason was given."));
    }

    function _handleInitiateError(message) {
        _serviceMissing(message);
        _fail("install", "The update could not be started.");
    }
}
