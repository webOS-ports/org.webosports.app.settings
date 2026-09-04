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
 * The passcode dialogs the legacy Screen & Lock app had, plus the Pattern
 * lock Android has and webOS never did.
 *
 * "verify" is the original's PinUnlock/PasswordUnlock: prove you know the
 * current passcode before the lock may be changed or taken off.
 * "set" is its SetPasswordDialog: the new passcode, twice, so a typo does not
 * lock the device.
 *
 * A pattern is not typed, so it does not fit the PIN/password two-field
 * layout: drawing it once is "verify", drawing it twice - the second has to
 * match the first - is "set". Both still end up calling verifyRequested or
 * chosen with a single string, the nine dots joined by their index
 * ("0-1-2-5-8"), which is all setDevicePasscode and matchDevicePasscode ever
 * wanted: an opaque passCode they compare for equality. A pattern is just
 * another string as far as the service is concerned.
 *
 * Verifying is the page's job - it is the one holding the service - so this
 * only reports what was drawn or typed and shows whatever the page hands
 * back as an error.
 */
Popup {
    id: passcodePopup

    // "verify" or "set"
    property string mode: "set"
    // "pin", "password" or "pattern"
    property string lockMode: "pin"
    property string errorText: ""
    // Set by the page: true when this "set" is the second half of changing
    // or removing an existing lock (a "verify" of the current one already
    // happened), false for a first-time "set" with nothing to replace. Only
    // changes the pattern prompt wording - Secure Unlock never reaches
    // "verify" any other way, so that prompt does not need the flag.
    property bool isChange: false

    signal verifyRequested(string passcode)
    signal chosen(string passcode)
    signal cancelled()

    readonly property bool isPin: lockMode === "pin"
    readonly property bool isPattern: lockMode === "pattern"
    readonly property int pinLength: 4

    // Pattern "set" is drawn twice; this holds the first draw while the
    // second is collected, and is what "confirming" below keys off.
    property string _firstPattern: ""
    readonly property bool _confirmingPattern: isPattern && mode === "set" && _firstPattern !== ""

    modal: true
    focus: true
    closePolicy: Popup.NoAutoClose

    width: Math.min(parent.width - Units.gu(4), Units.gu(40))
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    onOpened: {
        firstField.text = "";
        secondField.text = "";
        errorText = "";
        _firstPattern = "";
        patternGrid.reset();
        if (!isPattern)
            firstField.forceActiveFocus();
    }

    // Called by the page when the service rejected what was drawn or typed.
    function reportFailure(reason) {
        errorText = reason;
        firstField.text = "";
        secondField.text = "";
        if (isPattern) {
            patternGrid.showError();
            mismatchTimer.restart();
        } else {
            firstField.forceActiveFocus();
        }
    }

    readonly property bool entryValid: {
        if (isPattern)
            return false; // a pattern submits itself the moment it is drawn
        if (firstField.text.length === 0)
            return false;
        if (isPin && firstField.text.length !== pinLength)
            return false;
        if (mode === "set" && firstField.text !== secondField.text)
            return false;
        return true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Units.gu(1)

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: FontUtils.sizeToPixels("18pt")
            font.weight: Font.Bold
            text: {
                if (passcodePopup.isPattern) {
                    if (passcodePopup.mode === "verify")
                        return "Draw your current pattern";
                    if (passcodePopup._confirmingPattern)
                        return "Confirm pattern";
                    return passcodePopup.isChange ? "Draw a new pattern" : "Draw a pattern";
                }
                return passcodePopup.mode === "verify"
                       ? (passcodePopup.isPin ? "Enter your PIN" : "Enter your password")
                       : (passcodePopup.isPin ? "Choose a PIN" : "Choose a password");
            }
        }

        PatternLockGrid {
            id: patternGrid
            Layout.alignment: Qt.AlignHCenter
            visible: passcodePopup.isPattern

            onPatternDrawn: (encoded) => passcodePopup._patternDrawn(encoded)
            onTooShort: {
                passcodePopup.errorText = "Draw a pattern connecting at least 4 dots.";
                patternGrid.reset();
            }
        }

        TextField {
            id: firstField
            Layout.fillWidth: true
            Layout.preferredHeight: Units.gu(5)
            visible: !passcodePopup.isPattern
            echoMode: TextInput.Password
            // A PIN is digits only, and short enough to stop at four.
            inputMethodHints: passcodePopup.isPin
                              ? (Qt.ImhDigitsOnly | Qt.ImhNoPredictiveText)
                              : (Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhSensitiveData)
            // A four digit PIN, digits only. Kept as a length limit and a
            // filter rather than a validator: a QtQuick 2.9 import has no
            // regular expression validator, and an IntValidator would eat the
            // leading zero of a PIN like 0421.
            maximumLength: passcodePopup.isPin ? passcodePopup.pinLength : 0
            onTextChanged: if (passcodePopup.isPin) text = passcodePopup._digitsOnly(text)
            placeholderText: passcodePopup.isPin ? "PIN" : "Password"

            onAccepted: if (passcodePopup.entryValid) passcodePopup._submit()
        }

        TextField {
            id: secondField
            Layout.fillWidth: true
            Layout.preferredHeight: Units.gu(5)
            visible: !passcodePopup.isPattern && passcodePopup.mode === "set"
            echoMode: TextInput.Password
            inputMethodHints: firstField.inputMethodHints
            maximumLength: passcodePopup.isPin ? passcodePopup.pinLength : 0
            onTextChanged: if (passcodePopup.isPin) text = passcodePopup._digitsOnly(text)
            placeholderText: passcodePopup.isPin ? "Confirm PIN" : "Confirm password"

            onAccepted: if (passcodePopup.entryValid) passcodePopup._submit()
        }

        Label {
            Layout.fillWidth: true
            visible: text !== ""
            wrapMode: Text.WordWrap
            horizontalAlignment: passcodePopup.isPattern ? Text.AlignHCenter : Text.AlignLeft
            color: "#be0003"
            font.pixelSize: FontUtils.sizeToPixels("small")
            text: {
                if (passcodePopup.errorText !== "")
                    return passcodePopup.errorText;
                if (!passcodePopup.isPattern && passcodePopup.mode === "set" &&
                    secondField.text.length > 0 && firstField.text !== secondField.text)
                    return passcodePopup.isPin ? "The PINs do not match."
                                               : "The passwords do not match.";
                return "";
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Units.gu(1)

            Button {
                Layout.fillWidth: true
                text: "Cancel"
                LuneOSButton.mainColor: LuneOSButton.secondaryColor
                onClicked: {
                    passcodePopup.cancelled();
                    passcodePopup.close();
                }
            }
            Button {
                Layout.fillWidth: true
                visible: !passcodePopup.isPattern
                text: passcodePopup.mode === "verify" ? "Continue" : "Save"
                LuneOSButton.mainColor: LuneOSButton.affirmativeColor
                enabled: passcodePopup.entryValid
                onClicked: passcodePopup._submit()
            }
        }
    }

    // A pattern that failed to match (either a redraw mismatch during "set",
    // or a wrong verify) flashes red briefly, then clears for another try -
    // there is no "Save" button waiting to be pressed again.
    Timer {
        id: mismatchTimer
        interval: 700
        onTriggered: {
            passcodePopup._firstPattern = "";
            patternGrid.reset();
        }
    }

    function _digitsOnly(value) {
        var digits = "";
        for (var i = 0; i < value.length; i++) {
            if (value[i] >= "0" && value[i] <= "9")
                digits += value[i];
        }
        return digits;
    }

    function _patternDrawn(encoded) {
        if (mode === "verify") {
            // Left open: the page closes it once the service has agreed, so
            // a wrong pattern can be redrawn without reopening.
            verifyRequested(encoded);
            return;
        }

        if (_firstPattern === "") {
            // First draw of a "set": hold it and ask for the same pattern
            // again, exactly as the PIN/password fields ask twice.
            _firstPattern = encoded;
            patternGrid.reset();
            return;
        }

        if (encoded === _firstPattern) {
            chosen(encoded);
            close();
        } else {
            errorText = "The patterns do not match.";
            patternGrid.showError();
            mismatchTimer.restart();
        }
    }

    function _submit() {
        if (mode === "verify") {
            verifyRequested(firstField.text);
        } else {
            chosen(firstField.text);
            close();
        }
    }
}
