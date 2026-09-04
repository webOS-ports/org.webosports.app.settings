/*
 * (c) 2017 Christophe Chapuis <chris.chapuis@gmail.com>
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
 * Text Assist, after the webOS 3.0.5 app of the same name
 * (com.palm.app.textassist).
 *
 * Same shape as the original: a Text Correction group of switches, a button
 * into the user dictionary, and an Input Method group underneath.
 *
 * What moved, and why:
 *  - the switches were x_palm_textinput (spellChecking / grammarChecking /
 *    shortcutChecking). LuneOS's keyboard is the Ubuntu Touch one, and it
 *    reads a "keyboard" preference object instead, with its own
 *    autoCapitalization, autoCorrection, spellChecking and predictiveText.
 *    Those are the switches here, so each one moves something the keyboard
 *    actually reads. Predictive Text and Spell Checking are new rows: the
 *    keyboard has them and nothing on the device could turn them on.
 *  - "Double Space For Period" is gone. It was a webOS virtual keyboard
 *    behaviour (spaces2period) that this keyboard does not have.
 *  - the correction alert selector (System Sound / Vibrate / Mute) is gone
 *    with the com.palm.audio TextEntryCorrectionHapticPolicy it set. Key
 *    press feedback lives on the Sounds & Ringtones page.
 *  - the Input Method group offered other input methods to switch between.
 *    There is one keyboard on LuneOS, so the group holds what that keyboard
 *    can actually be told: its layout and its size.
 *
 * The user dictionary is stored in db8 under this app's own kinds - that is
 * what this page and its popup read and write, and it is also, now, what
 * the keyboard itself reads: webos-keyboard's SpellChecker
 * (plugins/westernsupport/spellchecker.cpp) and presage's Db8Predictor
 * (meta-webos-ports' presage recipe) both hold a standing db8 subscription
 * of their own on org.webosports.app.settings.dictionary:1 rather than
 * reading a file this page would otherwise have to keep in sync. db8 is the
 * only place a word gets added or removed, by any of the three - this page,
 * the keyboard's own long-press "add to dictionary", or a db8 restore
 * (which always ends in a reboot on this platform, so the standing
 * subscriptions above just pick the restored list back up).
 */
BasePage {
    id: pageRoot

    readonly property string wordsKind: "org.webosports.app.settings.dictionary:1"
    readonly property string shortcutsKind: "org.webosports.app.settings.shortcuts:1"

    property bool autoCapitalization: true
    property bool autoCorrection: true
    property bool spellChecking: true
    property bool predictiveText: true
    property string keyboardLayout: "LuneOS"
    property string keyboardSize: "M"

    // Kept whole: keyPressFeedback, enabledLanguages and activeLanguage in
    // here belong to other pages, and writing the object back without them
    // would wipe them.
    property var keyboardPrefs: ({})
    property bool prefsLoaded: false

    property var words: []
    property var shortcuts: []

    // The layouts and sizes webos-keyboard accepts.
    readonly property var layoutValues: ["LuneOS", "Dvorak", "Thumb"]
    readonly property var sizeValues: ["XS", "S", "M", "L"]
    readonly property var sizeLabels: ["Extra small", "Small", "Medium", "Large"]

    Component.onCompleted: {
        retrieveProperties();
        ensureDictionaryKinds();
    }

    function _indexOf(values, value, fallback) {
        var at = values.indexOf(value);
        return at >= 0 ? at : fallback;
    }

    SettingsPageContent {
        GroupBox {
            width: parent.width
            title: "Text Correction"

            Column {
                width: parent.width

                LabelAndSwitch {
                    id: autoCapSwitch
                    label: "Auto-Capitalization"

                    checked: pageRoot.autoCapitalization
                    Connections {
                        target: pageRoot
                        function onAutoCapitalizationChanged() {
                            autoCapSwitch.checked = pageRoot.autoCapitalization;
                        }
                    }
                    onToggled: pageRoot.setKeyboardPreference("autoCapitalization", checked)
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndSwitch {
                    id: autoCorrectSwitch
                    label: "Auto-Correction"

                    checked: pageRoot.autoCorrection
                    Connections {
                        target: pageRoot
                        function onAutoCorrectionChanged() {
                            autoCorrectSwitch.checked = pageRoot.autoCorrection;
                        }
                    }
                    onToggled: pageRoot.setKeyboardPreference("autoCorrection", checked)
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndSwitch {
                    id: spellCheckSwitch
                    label: "Spell Checking"

                    checked: pageRoot.spellChecking
                    Connections {
                        target: pageRoot
                        function onSpellCheckingChanged() {
                            spellCheckSwitch.checked = pageRoot.spellChecking;
                        }
                    }
                    onToggled: pageRoot.setKeyboardPreference("spellChecking", checked)
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndSwitch {
                    id: predictiveSwitch
                    label: "Predictive Text"

                    checked: pageRoot.predictiveText
                    Connections {
                        target: pageRoot
                        function onPredictiveTextChanged() {
                            predictiveSwitch.checked = pageRoot.predictiveText;
                        }
                    }
                    onToggled: pageRoot.setKeyboardPreference("predictiveText", checked)
                }
            }
        }

        ExplanationText {
            text: "Auto-correction fixes a word as you finish it. Spell checking " +
                  "only underlines it. Predictive text offers the next word above " +
                  "the keyboard."
        }

        Button {
            width: parent.width
            text: "Edit User Dictionary"
            onClicked: dictionaryPopup.open()
        }

        GroupBox {
            width: parent.width
            title: "Keyboard"

            Column {
                width: parent.width

                LabelAndSelector {
                    id: layoutSelector
                    width: parent.width
                    label: "Layout"
                    model: pageRoot.layoutValues

                    currentIndex: pageRoot._indexOf(pageRoot.layoutValues,
                                                    pageRoot.keyboardLayout, 0)
                    Connections {
                        target: pageRoot
                        function onKeyboardLayoutChanged() {
                            layoutSelector.currentIndex =
                                pageRoot._indexOf(pageRoot.layoutValues,
                                                  pageRoot.keyboardLayout, 0);
                        }
                    }
                    onActivated: (index) => pageRoot.setKeyboardPreference(
                                     "keyboardLayout", pageRoot.layoutValues[index])
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndSelector {
                    id: sizeSelector
                    width: parent.width
                    label: "Size"
                    model: pageRoot.sizeLabels

                    currentIndex: pageRoot._indexOf(pageRoot.sizeValues,
                                                    pageRoot.keyboardSize, 2)
                    Connections {
                        target: pageRoot
                        function onKeyboardSizeChanged() {
                            sizeSelector.currentIndex =
                                pageRoot._indexOf(pageRoot.sizeValues,
                                                  pageRoot.keyboardSize, 2);
                        }
                    }
                    onActivated: (index) => pageRoot.setKeyboardPreference(
                                     "keyboardSize", pageRoot.sizeValues[index])
                }
            }
        }

        ExplanationText {
            text: "Which languages the keyboard offers is set under Regional Settings."
        }
    }

    DictionaryPopup {
        id: dictionaryPopup

        words: pageRoot.words
        shortcuts: pageRoot.shortcuts

        onAddWordRequested: (word) => pageRoot.addWord(word)
        onRemoveWordRequested: (id) => pageRoot.removeEntry(id)
        onAddShortcutRequested: (shortcut, substitution) =>
                                    pageRoot.addShortcut(shortcut, substitution)
        onRemoveShortcutRequested: (id) => pageRoot.removeEntry(id)
    }

    /*
     * Keyboard preferences
     */
    function retrieveProperties() {
        luna.subscribe("luna://com.webos.service.systemservice/getPreferences",
                       JSON.stringify({"keys": ["keyboard"], "subscribe": true}),
                       _handleGetPreferences, _handleGetError);
    }

    function _handleGetPreferences(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.hasOwnProperty("keyboard"))
            return;

        var keyboardValue = response.keyboard;
        // Written as an object, but a JSON string is what the old apps left
        // behind, so take either.
        if (typeof keyboardValue === "string") {
            try {
                keyboardValue = JSON.parse(keyboardValue);
            } catch (e) {
                console.warn("Cannot parse the keyboard preferences: " + e);
                keyboardValue = {};
            }
        }

        pageRoot.keyboardPrefs = keyboardValue || {};

        if (pageRoot.keyboardPrefs.hasOwnProperty("autoCapitalization"))
            pageRoot.autoCapitalization = pageRoot.keyboardPrefs.autoCapitalization;
        if (pageRoot.keyboardPrefs.hasOwnProperty("autoCorrection"))
            pageRoot.autoCorrection = pageRoot.keyboardPrefs.autoCorrection;
        if (pageRoot.keyboardPrefs.hasOwnProperty("spellChecking"))
            pageRoot.spellChecking = pageRoot.keyboardPrefs.spellChecking;
        if (pageRoot.keyboardPrefs.hasOwnProperty("predictiveText"))
            pageRoot.predictiveText = pageRoot.keyboardPrefs.predictiveText;
        if (pageRoot.keyboardPrefs.hasOwnProperty("keyboardLayout"))
            pageRoot.keyboardLayout = pageRoot.keyboardPrefs.keyboardLayout;
        if (pageRoot.keyboardPrefs.hasOwnProperty("keyboardSize"))
            pageRoot.keyboardSize = pageRoot.keyboardPrefs.keyboardSize;

        pageRoot.prefsLoaded = true;
    }

    function setKeyboardPreference(key, value) {
        if (!pageRoot.prefsLoaded) {
            console.log("Trying to set preferences before reading them first: ignoring.");
            return;
        }

        if (key === "autoCapitalization")
            pageRoot.autoCapitalization = value;
        else if (key === "autoCorrection")
            pageRoot.autoCorrection = value;
        else if (key === "spellChecking")
            pageRoot.spellChecking = value;
        else if (key === "predictiveText")
            pageRoot.predictiveText = value;
        else if (key === "keyboardLayout")
            pageRoot.keyboardLayout = value;
        else if (key === "keyboardSize")
            pageRoot.keyboardSize = value;

        var prefs = {};
        for (var existing in pageRoot.keyboardPrefs)
            prefs[existing] = pageRoot.keyboardPrefs[existing];
        prefs[key] = value;
        pageRoot.keyboardPrefs = prefs;

        luna.call("luna://com.webos.service.systemservice/setPreferences",
                  JSON.stringify({"keyboard": prefs}),
                  _handleSetSuccess, _handleSetError);
    }

    /*
     * The user dictionary, in db8
     *
     * Two kinds of our own rather than one with a type field: they are
     * different shapes, and a shortcut has to be found by what you typed.
     */
    function ensureDictionaryKinds() {
        _putKind(wordsKind, [{"name": "word", "props": [{"name": "word"}]}],
                 function(message) { _grantWordsPermissions(); _loadWords(message); });
        _putKind(shortcutsKind, [{"name": "shortcut", "props": [{"name": "shortcut"}]}],
                 _loadShortcuts);
    }

    function _grantWordsPermissions() {
        // db8 kinds are owner-only by default (see putKind above) - Db8Predictor
        // (presage) and SpellChecker (webos-keyboard) read, and the keyboard
        // long-press add-to-dictionary also writes, this kind directly from
        // MaliitServer under their own LS2 identities. Without this grant every
        // com.palm.db call they make comes back permission denied even though
        // role.json already allows them onto the bus - that is a separate check.
        luna.call("luna://com.palm.db/putPermissions",
                  JSON.stringify({"permissions": [
                      {"type": "db.kind", "object": wordsKind,
                       "caller": "org.webosports.presage.dictionary",
                       "operations": {"read": "allow"}},
                      {"type": "db.kind", "object": wordsKind,
                       "caller": "org.webosports.keyboard.dictionary",
                       "operations": {"read": "allow", "create": "allow"}}
                  ]}),
                  function() {},
                  function(message) { console.log("putPermissions " + wordsKind + ": " + message); });
    }

    function _putKind(kind, indexes, onDone) {
        // "sync": true is what db8's own dump() filters on when the backup
        // service calls com.palm.db/internal/preBackup - the same flag
        // luna-next-cardshell's launcher kinds use (see BackupManager.cpp's
        // header comment in luna-sysmgr). The kind travels with the
        // database automatically; nothing else has to know this exists.
        luna.call("luna://com.palm.db/putKind",
                  JSON.stringify({"id": kind, "owner": appId, "indexes": indexes,
                                  "sync": true}),
                  onDone,
                  // Already registered is the usual answer here, and it is not
                  // a problem: read the list either way.
                  function(message) {
                      console.log("putKind " + kind + ": " + message);
                      onDone(null);
                  });
    }

    function _loadWords(message) {
        luna.call("luna://com.palm.db/find",
                  JSON.stringify({"query": {"from": pageRoot.wordsKind, "orderBy": "word"}}),
                  _handleWords, _handleGetError);
    }

    function _loadShortcuts(message) {
        luna.call("luna://com.palm.db/find",
                  JSON.stringify({"query": {"from": pageRoot.shortcutsKind,
                                            "orderBy": "shortcut"}}),
                  _handleShortcuts, _handleGetError);
    }

    function _handleWords(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        pageRoot.words = response.results !== undefined ? response.results : [];
    }

    function _handleShortcuts(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        pageRoot.shortcuts = response.results !== undefined ? response.results : [];
    }

    function addWord(word) {
        luna.call("luna://com.palm.db/put",
                  JSON.stringify({"objects": [{"_kind": pageRoot.wordsKind, "word": word}]}),
                  _loadWords, _handleSetError);
    }

    function addShortcut(shortcut, substitution) {
        luna.call("luna://com.palm.db/put",
                  JSON.stringify({"objects": [{"_kind": pageRoot.shortcutsKind,
                                               "shortcut": shortcut,
                                               "substitution": substitution}]}),
                  _loadShortcuts, _handleSetError);
    }

    function removeEntry(id) {
        luna.call("luna://com.palm.db/del", JSON.stringify({"ids": [id]}),
                  _handleEntryRemoved, _handleSetError);
    }

    function _handleEntryRemoved(message) {
        // Which list it came out of is not worth working out; both are short.
        _loadWords(message);
        _loadShortcuts(message);
    }
}
