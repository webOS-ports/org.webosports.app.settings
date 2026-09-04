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

import "../Common"

/*
 * Print Manager, after the webOS 3.0.5 app of the same name
 * (com.palm.app.printmanager).
 *
 * Same three things as the original: what is waiting to print and a way to
 * stop it, the printers the device knows about - the ones it found by itself
 * and the ones that were typed in - and a form to add another.
 *
 * The original drove com.palm.printmgr, HP's service around a bundled Canon
 * print stack. LuneOS has nothing of the sort, so this is written to a
 * CUPS-shaped service instead: everything below maps onto an IPP call, which
 * is what a small adapter over CUPS would be doing anyway. Until one is on the
 * bus the page says so rather than offering an Add button that goes nowhere.
 *
 * The contract a new org.webosports.service.print would have to implement:
 *
 *   listPrinters { subscribe: true }
 *     -> { returnValue, defaultPrinterId,
 *          printers: [ { printerId, name, uri, location, makeAndModel,
 *                        state, discovered } ] }
 *        state is the IPP printer-state: "idle", "processing" or "stopped".
 *        discovered is true for one found over DNS-SD, false for one added
 *        here - which is the split the original showed as "Auto Discovered"
 *        and "Manually Added".
 *
 *   listJobs { subscribe: true }
 *     -> { returnValue, jobs: [ { jobId, title, printerId, printerName,
 *                                 state, pages, completedPages } ] }
 *        state is the IPP job-state: "pending", "processing", "held",
 *        "stopped", "canceled", "aborted", "completed".
 *
 *   addPrinter        { name, uri }        -> { returnValue, printerId }
 *   removePrinter     { printerId }
 *   setDefaultPrinter { printerId }
 *   cancelJob         { jobId }
 *   cancelAllJobs     {}
 */
BasePage {
    id: pageRoot

    readonly property string printService: "org.webosports.service.print"

    property bool serviceAvailable: false
    property var printers: []
    property var jobs: []
    property string defaultPrinterId: ""

    Component.onCompleted: retrieveProperties();

    readonly property var discoveredPrinters: _printersWhere(true)
    readonly property var manualPrinters: _printersWhere(false)

    function _printersWhere(discovered) {
        var matches = [];
        for (var i = 0; i < printers.length; i++) {
            if ((printers[i].discovered === true) === discovered)
                matches.push(printers[i]);
        }
        return matches;
    }

    // Only a job that has not finished is worth showing or cancelling.
    readonly property var activeJobs: {
        var active = [];
        for (var i = 0; i < jobs.length; i++) {
            var state = jobs[i].state;
            if (state !== "completed" && state !== "canceled" && state !== "aborted")
                active.push(jobs[i]);
        }
        return active;
    }

    function jobStateText(job) {
        if (job.state === "processing") {
            // "3 of 8" is more use than "processing" while a long document
            // works its way through.
            if (job.pages > 0)
                return "Printing " + (job.completedPages + 1) + " of " + job.pages;
            return "Printing";
        }
        if (job.state === "pending")
            return "Waiting";
        if (job.state === "held")
            return "Held";
        if (job.state === "stopped")
            return "Stopped";
        return job.state;
    }

    function printerStateText(printer) {
        if (printer.state === "processing")
            return "Printing";
        if (printer.state === "stopped")
            return "Stopped";
        return "Ready";
    }

    SettingsPageContent {
        // Printer names and addresses read better with a bit more room than a
        // column of switches needs.
        maximumContentWidth: Units.gu(64)

        ServiceUnavailableNotice {
            visible: !pageRoot.serviceAvailable

            serviceName: pageRoot.printService
            description: "Nothing on this device can print yet. The rows below " +
                         "show what a print service would be asked for."

            onRetry: pageRoot.retrieveProperties()
        }

        GroupBox {
            width: parent.width
            enabled: pageRoot.serviceAvailable

            title: "Print Queue"
            Column {
                width: parent.width

                Repeater {
                    model: pageRoot.activeJobs

                    delegate: Column {
                        width: parent.width

                        Item {
                            width: parent.width
                            height: Units.gu(8)

                            RowLayout {
                                anchors.fill: parent
                                spacing: Units.gu(1)

                                Column {
                                    Layout.fillWidth: true

                                    Label {
                                        width: parent.width
                                        text: modelData.title
                                        elide: Text.ElideRight
                                        font.pixelSize: FontUtils.sizeToPixels("16pt")
                                    }
                                    Label {
                                        width: parent.width
                                        text: modelData.printerName + " - " +
                                              pageRoot.jobStateText(modelData)
                                        elide: Text.ElideRight
                                        color: "#666666"
                                        font.pixelSize: FontUtils.sizeToPixels("small")
                                    }
                                }

                                Button {
                                    text: "Cancel"
                                    LuneOSButton.mainColor: LuneOSButton.secondaryColor
                                    onClicked: pageRoot.cancelJob(modelData.jobId)
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
                    visible: pageRoot.activeJobs.length === 0
                    height: visible ? Units.gu(6) : 0
                    verticalAlignment: Text.AlignVCenter
                    text: "Currently there are no jobs in the printing queue."
                    color: "#666666"
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }
            }
        }

        Button {
            width: parent.width
            visible: pageRoot.activeJobs.length > 0
            enabled: pageRoot.serviceAvailable
            text: "Cancel All"
            LuneOSButton.mainColor: LuneOSButton.negativeColor
            LuneOSButton.textColor: "white"

            onClicked: pageRoot.cancelAllJobs()
        }

        GroupBox {
            width: parent.width
            enabled: pageRoot.serviceAvailable
            visible: pageRoot.discoveredPrinters.length > 0

            title: "Auto Discovered"
            Column {
                width: parent.width

                Repeater {
                    model: pageRoot.discoveredPrinters
                    delegate: printerRow
                }
            }
        }

        GroupBox {
            width: parent.width
            enabled: pageRoot.serviceAvailable

            title: "Manually Added"
            Column {
                width: parent.width

                Repeater {
                    model: pageRoot.manualPrinters
                    delegate: printerRow
                }

                Label {
                    width: parent.width
                    visible: pageRoot.manualPrinters.length === 0
                    height: visible ? Units.gu(6) : 0
                    verticalAlignment: Text.AlignVCenter
                    text: "No printer has been added by hand."
                    color: "#666666"
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }
            }
        }

        GroupBox {
            width: parent.width
            enabled: pageRoot.serviceAvailable

            title: "Add a Printer"
            Column {
                width: parent.width
                spacing: Units.gu(1)

                Label {
                    width: parent.width
                    text: "Give the printer a name and the address to reach it at."
                    wrapMode: Text.WordWrap
                    color: "#666666"
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }

                TextField {
                    id: newPrinterName
                    width: parent.width
                    height: Units.gu(5)
                    placeholderText: "Name printer"
                    inputMethodHints: Qt.ImhNoPredictiveText
                }

                TextField {
                    id: newPrinterAddress
                    width: parent.width
                    height: Units.gu(5)
                    placeholderText: "IP address or ipp:// address"
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase |
                                      Qt.ImhUrlCharactersOnly
                }

                Button {
                    width: parent.width
                    text: "Add Printer"
                    LuneOSButton.mainColor: LuneOSButton.affirmativeColor
                    enabled: newPrinterName.text.trim() !== "" &&
                             newPrinterAddress.text.trim() !== ""

                    onClicked: {
                        pageRoot.addPrinter(newPrinterName.text.trim(),
                                            newPrinterAddress.text.trim());
                        newPrinterName.text = "";
                        newPrinterAddress.text = "";
                    }
                }
            }
        }

        ExplanationText {
            text: "Tap a printer to make it the one that is printed to by " +
                  "default. Swipe one you added sideways to remove it."
        }
    }

    /*
     * One row shape for both printer lists: the difference between a
     * discovered printer and a typed-in one is only whether it can be removed.
     */
    Component {
        id: printerRow

        Item {
            id: row
            width: parent.width
            height: Units.gu(8)

            readonly property var printer: modelData
            property bool pendingDelete: false

            // Normal row: name, what it is and what it is doing.
            Item {
                anchors.fill: parent
                visible: !row.pendingDelete

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Units.gu(1)
                    anchors.rightMargin: Units.gu(1)
                    spacing: Units.gu(1)

                    Column {
                        Layout.fillWidth: true

                        Label {
                            width: parent.width
                            text: row.printer.name
                            elide: Text.ElideRight
                            font.bold: row.printer.printerId === pageRoot.defaultPrinterId
                            font.pixelSize: FontUtils.sizeToPixels("16pt")
                        }
                        Label {
                            width: parent.width
                            text: (row.printer.makeAndModel ? row.printer.makeAndModel + " - " : "") +
                                  pageRoot.printerStateText(row.printer)
                            elide: Text.ElideRight
                            color: "#666666"
                            font.pixelSize: FontUtils.sizeToPixels("small")
                        }
                    }

                    Label {
                        visible: row.printer.printerId === pageRoot.defaultPrinterId
                        text: "Default"
                        color: "#666666"
                        font.pixelSize: FontUtils.sizeToPixels("small")
                    }
                }

                // Tap the row to make it the default; swipe it sideways to ask
                // for delete confirmation (webOS delete gesture). A printer the
                // device found for itself comes back the moment it is deleted,
                // so only a typed-in one arms the confirmation.
                MouseArea {
                    anchors.fill: parent

                    property real _pressX: 0

                    // These rows sit directly in SettingsPageContent, which is
                    // a Flickable. Left alone it grabs the drag and this area
                    // never sees the release, so the swipe silently does
                    // nothing. Fingerprint gets away without this because its
                    // rows are inside a ListView that mediates the gesture.
                    // Claim the drag only once it is clearly sideways, so a
                    // vertical drag still scrolls the page.
                    onPressed: (mouse) => {
                        _pressX = mouse.x;
                        preventStealing = false;
                    }
                    onPositionChanged: (mouse) => {
                        if (Math.abs(mouse.x - _pressX) > Units.gu(2))
                            preventStealing = true;
                    }
                    onCanceled: { preventStealing = false; }
                    onReleased: (mouse) => {
                        preventStealing = false;
                        if (Math.abs(mouse.x - _pressX) > Units.gu(4)) {
                            if (!row.printer.discovered)
                                row.pendingDelete = true;
                        } else {
                            pageRoot.setDefaultPrinter(row.printer.printerId);
                        }
                    }
                }
            }

            // Delete confirmation: Cancel (grey) + Delete (red), centred,
            // matching the legacy webOS swipe-to-delete.
            Row {
                anchors.centerIn: parent
                spacing: Units.gu(2)
                visible: row.pendingDelete

                Button {
                    text: "Cancel"
                    LuneOSButton.mainColor: LuneOSButton.secondaryColor
                    onClicked: row.pendingDelete = false
                }

                Button {
                    text: "Delete"
                    LuneOSButton.mainColor: "#be0003"
                    LuneOSButton.textColor: "white"
                    onClicked: {
                        pageRoot.removePrinter(row.printer.printerId);
                        row.pendingDelete = false;
                    }
                }
            }

            HorizontalSeparator {
                anchors.bottom: parent.bottom
                width: parent.width
            }
        }
    }

    /*
     * Bindings with LuneOS settings
     */
    function retrieveProperties() {
        // Both subscribed: printers appear and disappear on the network, and
        // a queue that only refreshed on a tap would be no use at all.
        luna.subscribe("luna://" + printService + "/listPrinters",
                       JSON.stringify({"subscribe": true}),
                       _handleGetPrinters, _handleServiceUnavailable);

        luna.subscribe("luna://" + printService + "/listJobs",
                       JSON.stringify({"subscribe": true}),
                       _handleGetJobs, _handleServiceUnavailable);
    }

    function _handleGetPrinters(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue)
            return;

        pageRoot.printers = response.printers !== undefined ? response.printers : [];
        if (response.hasOwnProperty("defaultPrinterId"))
            pageRoot.defaultPrinterId = response.defaultPrinterId;

        pageRoot.serviceAvailable = true;
    }

    function _handleGetJobs(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue)
            return;

        pageRoot.jobs = response.jobs !== undefined ? response.jobs : [];
        pageRoot.serviceAvailable = true;
    }

    function _handleServiceUnavailable(message) {
        console.warn("Print service did not answer: " + message);
        pageRoot.serviceAvailable = false;
    }

    function _call(method, params) {
        luna.call("luna://" + pageRoot.printService + "/" + method,
                  JSON.stringify(params), _handleSetSuccess, _handleSetError);
    }

    function addPrinter(name, address) {
        // A bare host name or address is the common case; anything already
        // carrying a scheme is passed through as it was typed.
        var uri = address.indexOf("://") >= 0 ? address : "ipp://" + address + "/ipp/print";
        _call("addPrinter", {"name": name, "uri": uri});
    }

    function removePrinter(printerId) {
        _call("removePrinter", {"printerId": printerId});
    }

    function setDefaultPrinter(printerId) {
        pageRoot.defaultPrinterId = printerId;
        _call("setDefaultPrinter", {"printerId": printerId});
    }

    function cancelJob(jobId) {
        _call("cancelJob", {"jobId": jobId});
    }

    function cancelAllJobs() {
        _call("cancelAllJobs", {});
    }
}
