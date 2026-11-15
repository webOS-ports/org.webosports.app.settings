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
import QtQuick.Layouts 1.3
import Qt.labs.folderlistmodel 2.1

// Theme specific properties
import QtQuick.Controls.LuneOS 2.0
// Units & font sizes
import LunaNext.Common 0.1

import "../Common"
import "../Common/LanguageNames.js" as LanguageNames
import LuneOS.Forms 1.0
import LuneOS.System 1.0

/*
 * Regional Settings, after the webOS 3.0.5 app of the same name
 * (com.palm.app.languagepicker, its regionalsettings scene).
 *
 * Same rows in the same order as the original: the display language, the
 * keyboards (each one installed with an On/Off switch, and the default one
 * above them), the region used for phone numbers,
 * the region used for date, time, number and currency formats, a live preview
 * of those formats, and the Apply button that only appears once something has
 * actually changed.
 *
 * The locale and region halves are luna-sysservice, which LuneOS carries
 * unchanged: getPreferences for what is set, getPreferenceValues for what may
 * be set, setPreferences to change it.
 *
 * The keyboards half moved. webOS kept them in x_palm_virtualkeyboard_prefs as
 * a JSON string of layout/language pairs; LuneOS's keyboard is the Ubuntu
 * Touch one, and it reads a "keyboard" preference object with
 * enabledLanguages (a list of codes) and activeLanguage (the one in force).
 * So the rows look the same and the storage underneath is the current one.
 *
 * One thing to know about the phone row: LuneOS's phone app parses numbers
 * with the top-level "region" preference - the one the Formats row sets - and
 * nothing reads currentLocale.phoneRegion yet. The row is kept because that is where
 * the setting belongs and where a ported app would look for it, and the note
 * underneath says which one is in force today.
 */
BasePage {
    id: pageRoot

    // What is set now
    property var currentLocale: ({})
    property var region: ({})

    // What may be set - both come from getPreferenceValues
    property var availableLocales: []
    property var availableRegions: []

    // The keyboard preference object, kept whole: only enabledLanguages and
    // activeLanguage are ours, and the rest belongs to the keyboard.
    property var keyboardPrefs: ({})
    property var enabledKeyboards: []
    property string activeKeyboard: ""

    // What was in force when the page opened, so the Apply button can tell
    // whether anything is actually pending.
    property var originalLocale: ({})
    property var originalRegion: ({})

    readonly property bool prefsLoaded: prefs.loaded

    SystemPreferences {
        id: prefs
        clientName: appId
        keys: ["locale", "region", "keyboard"]
        onUpdated: (response) => pageRoot._handleGetPreferences(response)
    }

    /*
     * The languages the keyboard can type. There is no call that lists them,
     * so they are read off the keyboard's own install: one directory per
     * language under its lib/, named by the code it matches against - which
     * is the one place that cannot disagree with what the device has (the
     * Q25 image has no Chinese, and does have Norwegian and Ukrainian).
     *
     * The keyboard keeps only the first two letters of each enabled
     * language, so the code here has to be the two-letter one: Pinyin
     * installs as lib/zh, and "pinyin" came out as "pi", which no layout
     * matches. Where the directory cannot be read (the desktop) this falls
     * back to the keyboard's own supported list (KeyboardContainer.qml).
     */
    readonly property var _keyboardFallback: [
        "ar", "cs", "da", "de", "en", "es", "fi", "fr", "he", "hu",
        "it", "nl", "no", "pl", "pt", "ru", "sv", "uk", "zh"
    ]
    property var _installedKeyboards: []
    readonly property var keyboardLanguageCodes: _installedKeyboards.length > 0
                                                 ? _installedKeyboards : _keyboardFallback

    FolderListModel {
        id: installedKeyboardModel
        folder: "file:///usr/share/maliit/plugins/org/luneos/lib"
        showFiles: false
        showDirs: true
        showDotAndDotDot: false
        onCountChanged: pageRoot._readInstalledKeyboards()
    }

    function _readInstalledKeyboards() {
        var codes = [];
        for (var i = 0; i < installedKeyboardModel.count; i++) {
            var name = installedKeyboardModel.get(i, "fileName");
            if (/^[a-z][a-z]$/.test(name))
                codes.push(name);
        }
        pageRoot._installedKeyboards = codes;
    }

    /*
     * The rows of the Keyboards group: every keyboard installed, and any
     * enabled one that is not (so it can still be turned off), by name.
     */
    readonly property var keyboardRows: {
        var codes = keyboardLanguageCodes.slice();
        for (var i = 0; i < enabledKeyboards.length; i++) {
            if (codes.indexOf(enabledKeyboards[i]) < 0)
                codes.push(enabledKeyboards[i]);
        }
        codes.sort(function(a, b) { return keyboardLabel(a).localeCompare(keyboardLabel(b)); });
        return codes;
    }

    // Chinese is typed in Pinyin; it is the only layout that says how
    function keyboardLabel(code) {
        return (code === "zh" || code === "pinyin") ? "Chinese (Pinyin)"
                                                    : LanguageNames.nameForCode(code);
    }

    Component.onCompleted: retrieveProperties();

    readonly property bool hasPendingChanges: {
        if (!prefsLoaded)
            return false;

        return currentLocale.languageCode !== originalLocale.languageCode ||
               currentLocale.countryCode !== originalLocale.countryCode ||
               region.countryCode !== originalRegion.countryCode ||
               _phoneRegionCode(currentLocale) !== _phoneRegionCode(originalLocale);
    }

    // The locale drives the format previews, so they change the moment a
    // region is picked rather than waiting for the restart.
    readonly property var previewLocale:
        Qt.locale((currentLocale.languageCode ? currentLocale.languageCode : "en") + "_" +
                  (region.countryCode ? region.countryCode.toUpperCase() : "US"))

    SettingsPageContent {
        GroupBox {
            width: parent.width
            title: "Language"

            LabelAndPicker {
                width: parent.width
                label: "Language"
                value: pageRoot.localeDescription()
                placeholder: "Pick a language"

                onClicked: {
                    languagePicker.entries = pageRoot.languageEntries();
                    languagePicker.currentKey = pageRoot.currentLocale.languageCode
                                                ? pageRoot.currentLocale.languageCode : "";
                    languagePicker.open();
                }
            }
        }

        /*
         * Keyboards. The original listed the ones set up, to swipe away, with
         * an Add row for the rest. Here every keyboard the device has is a
         * row with a switch, so what can be typed in is all in one place. The
         * last one on cannot be turned off: the keyboard needs a language.
         * Default is the one the keyboard comes up in (activeLanguage).
         */
        GroupBox {
            width: parent.width
            title: "Keyboards"

            Column {
                width: parent.width

                LabelAndPicker {
                    width: parent.width
                    label: "Default"
                    value: pageRoot.activeKeyboard !== "" ? pageRoot.keyboardLabel(pageRoot.activeKeyboard) : ""
                    placeholder: "No keyboard is on"
                    enabled: pageRoot.enabledKeyboards.length > 0

                    onClicked: {
                        defaultKeyboardPicker.entries = pageRoot.defaultKeyboardEntries();
                        defaultKeyboardPicker.currentKey = pageRoot.activeKeyboard;
                        defaultKeyboardPicker.open();
                    }
                }

                Repeater {
                    model: pageRoot.keyboardRows

                    delegate: Column {
                        width: parent.width

                        HorizontalSeparator {
                            width: parent.width
                        }

                        LabelAndSwitch {
                            id: keyboardSwitch
                            readonly property bool on: pageRoot.enabledKeyboards.indexOf(modelData) >= 0

                            width: parent.width
                            label: pageRoot.keyboardLabel(modelData)
                            checked: on
                            // Toggling a switch ends its binding: it follows the
                            // preference again whenever that changes.
                            onOnChanged: keyboardSwitch.checked = on
                            enabled: !(on && pageRoot.enabledKeyboards.length === 1)
                            onToggled: {
                                pageRoot.setKeyboardEnabled(modelData, checked);
                                keyboardSwitch.checked = on;
                            }
                        }
                    }
                }
            }
        }

        ExplanationText {
            text: "Turn on the keyboards you want to type in, and switch between " +
                  "them on the keyboard. The default keyboard is the one that comes up first."
        }

        GroupBox {
            width: parent.width
            title: "Phone Numbers"

            LabelAndPicker {
                width: parent.width
                label: "Region"
                value: pageRoot.phoneRegionName()
                placeholder: "No region set"

                onClicked: {
                    phoneRegionPicker.entries = pageRoot.regionEntries();
                    phoneRegionPicker.currentKey = pageRoot._phoneRegionCode(pageRoot.currentLocale);
                    phoneRegionPicker.open();
                }
            }
        }

        ExplanationText {
            text: "The region for contacts and phone numbers that do not carry " +
                  "a country code. Today the phone app reads the Formats region " +
                  "below for this."
        }

        GroupBox {
            width: parent.width
            title: "Formats"

            LabelAndPicker {
                width: parent.width
                label: "Region"
                value: pageRoot.region.countryName ? pageRoot.region.countryName : ""
                placeholder: "Pick a region"

                onClicked: {
                    regionPicker.entries = pageRoot.regionEntries();
                    regionPicker.currentKey = pageRoot.region.countryCode
                                              ? pageRoot.region.countryCode : "";
                    regionPicker.open();
                }
            }
        }

        ExplanationText {
            text: "Select the country whose date, time, number and currency " +
                  "formats you want to use."
        }

        /*
         * The preview the original showed, so you can see what a region does
         * before committing to a restart.
         */
        GroupBox {
            width: parent.width
            title: "Format Previews"

            Column {
                width: parent.width

                LabelAndValue {
                    width: parent.width
                    label: "Number"
                    value: Number(123456789.12).toLocaleString(pageRoot.previewLocale)
                }
                LabelAndValue {
                    width: parent.width
                    label: "Currency"
                    value: Number(123456789.12).toLocaleCurrencyString(pageRoot.previewLocale)
                }
                LabelAndValue {
                    width: parent.width
                    label: "Time"
                    value: new Date().toLocaleTimeString(pageRoot.previewLocale, Locale.ShortFormat)
                }
                LabelAndValue {
                    width: parent.width
                    label: "Short"
                    value: new Date().toLocaleDateString(pageRoot.previewLocale, Locale.ShortFormat)
                }
                LabelAndValue {
                    width: parent.width
                    label: "Long"
                    value: new Date().toLocaleDateString(pageRoot.previewLocale, Locale.LongFormat)
                }
            }
        }

        /*
         * Only shown once something is pending, the way the original's Apply
         * button appeared. The locale is read by services when they start, so
         * it does not take fully until they are restarted - which is why the
         * original called this "Apply Changes and Reboot".
         */
        Button {
            width: parent.width
            visible: pageRoot.hasPendingChanges
            text: "Apply Changes and Restart"
            LuneOSButton.mainColor: LuneOSButton.negativeColor
            LuneOSButton.textColor: "white"

            onClicked: applyDialog.open()
        }
    }

    ListPickerPopup {
        id: languagePicker
        title: "Language"
        emptyText: "The system service reported no languages."

        onPicked: (key, entry) => pageRoot.chooseLanguage(key)
    }

    ListPickerPopup {
        id: countryPicker
        title: "Country"

        onPicked: (key, entry) => pageRoot.chooseLanguageCountry(key)
    }

    ListPickerPopup {
        id: regionPicker
        title: "Formats"
        emptyText: "The system service reported no regions."

        onPicked: (key, entry) => pageRoot.chooseRegion(key, entry.label)
    }

    ListPickerPopup {
        id: phoneRegionPicker
        title: "Phone Numbers"
        emptyText: "The system service reported no regions."

        onPicked: (key, entry) => pageRoot.choosePhoneRegion(key, entry.label)
    }

    ListPickerPopup {
        id: defaultKeyboardPicker
        title: "Default Keyboard"

        onPicked: (key, entry) => pageRoot.setActiveKeyboard(key)
    }

    Dialog {
        id: applyDialog

        modal: true
        width: Math.min(parent.width - Units.gu(4), Units.gu(40))

        title: "Apply Regional Settings"

        contentItem: Label {
            // Without an explicit width tied to the dialog's own (already
            // fixed, non-content-derived) width, a word-wrapped Label's
            // implicitHeight and the Dialog's implicitHeight end up depending
            // on each other - "Binding loop detected for property
            // implicitHeight" on real hardware, never on desktop where the
            // dialog was never actually opened during testing.
            width: applyDialog.availableWidth
            wrapMode: Text.WordWrap
            padding: Units.gu(1)
            text: "Services read the language and region when they start, so " +
                  "the device has to restart for the change to take everywhere."
            font.pixelSize: FontUtils.sizeToPixels("medium")
        }

        /*
         * Stacked and full width, the way webOS dialogs laid out their
         * buttons, with Cancel last. Side by side the three ran past the
         * dialog's edge on a 720px wide screen.
         */
        footer: Column {
            spacing: Units.gu(1)
            // The dialog art's 25px frame at the sides and the bottom
            leftPadding: 25
            rightPadding: 25
            bottomPadding: 25

            Button {
                width: parent.width - parent.leftPadding - parent.rightPadding
                text: "Apply and Restart"
                LuneOSButton.mainColor: LuneOSButton.negativeColor
                LuneOSButton.textColor: "white"
                onClicked: {
                    pageRoot.applyChanges();
                    pageRoot.restartDevice();
                    applyDialog.close();
                }
            }
            Button {
                width: parent.width - parent.leftPadding - parent.rightPadding
                // Writing the preferences without restarting is worth having
                // on its own: a newly started app already picks them up.
                text: "Apply Only"
                onClicked: {
                    pageRoot.applyChanges();
                    applyDialog.close();
                }
            }
            Button {
                width: parent.width - parent.leftPadding - parent.rightPadding
                text: "Cancel"
                LuneOSButton.mainColor: LuneOSButton.secondaryColor
                onClicked: applyDialog.close()
            }
        }
    }

    /*
     * Reading the current settings
     */
    function localeDescription() {
        if (!currentLocale.languageCode)
            return "";

        var languageName = LanguageNames.nameForCode(currentLocale.languageCode);
        for (var i = 0; i < availableLocales.length; i++) {
            if (availableLocales[i].languageCode !== currentLocale.languageCode)
                continue;

            languageName = availableLocales[i].languageName;
            var countries = availableLocales[i].countries || [];
            for (var j = 0; j < countries.length; j++) {
                if (countries[j].countryCode === currentLocale.countryCode)
                    return languageName + " (" + countries[j].countryName + ")";
            }
        }
        return languageName;
    }

    function _phoneRegionCode(someLocale) {
        return someLocale && someLocale.phoneRegion && someLocale.phoneRegion.countryCode
               ? someLocale.phoneRegion.countryCode : "";
    }

    function phoneRegionName() {
        if (currentLocale.phoneRegion && currentLocale.phoneRegion.countryName)
            return currentLocale.phoneRegion.countryName;
        return "";
    }

    /*
     * Turning the service's lists into picker entries
     */
    function languageEntries() {
        var entries = [];
        for (var i = 0; i < availableLocales.length; i++) {
            entries.push({
                "key": availableLocales[i].languageCode,
                "label": availableLocales[i].languageName
            });
        }
        return entries;
    }

    function countryEntriesFor(languageCode) {
        for (var i = 0; i < availableLocales.length; i++) {
            if (availableLocales[i].languageCode !== languageCode)
                continue;

            var countries = availableLocales[i].countries || [];
            var entries = [];
            for (var j = 0; j < countries.length; j++) {
                entries.push({
                    "key": countries[j].countryCode,
                    "label": countries[j].countryName
                });
            }
            return entries;
        }
        return [];
    }

    function regionEntries() {
        var entries = [];
        for (var i = 0; i < availableRegions.length; i++) {
            entries.push({
                "key": availableRegions[i].countryCode,
                "label": availableRegions[i].countryName
            });
        }
        return entries;
    }

    // The keyboards that are on, for the Default picker, by name
    function defaultKeyboardEntries() {
        var entries = [];
        for (var i = 0; i < enabledKeyboards.length; i++) {
            entries.push({
                "key": enabledKeyboards[i],
                "label": pageRoot.keyboardLabel(enabledKeyboards[i])
            });
        }
        entries.sort(function(a, b) { return a.label.localeCompare(b.label); });
        return entries;
    }

    /*
     * Making a choice. Nothing is written until Apply: the original held the
     * locale back the same way, because changing it mid-session leaves half
     * the device in the old language.
     */
    function chooseLanguage(languageCode) {
        var countries = countryEntriesFor(languageCode);

        var newLocale = _copy(currentLocale);
        newLocale.languageCode = languageCode;
        // A language spoken in one country only needs no second question.
        if (countries.length <= 1)
            newLocale.countryCode = countries.length === 1 ? countries[0].key : languageCode;
        pageRoot.currentLocale = newLocale;

        if (countries.length > 1) {
            countryPicker.entries = countries;
            countryPicker.currentKey = currentLocale.countryCode ? currentLocale.countryCode : "";
            countryPicker.open();
        }
    }

    function chooseLanguageCountry(countryCode) {
        var newLocale = _copy(currentLocale);
        newLocale.countryCode = countryCode;
        pageRoot.currentLocale = newLocale;
    }

    function chooseRegion(countryCode, countryName) {
        pageRoot.region = { "countryCode": countryCode, "countryName": countryName };
    }

    function choosePhoneRegion(countryCode, countryName) {
        var newLocale = _copy(currentLocale);
        newLocale.phoneRegion = { "countryCode": countryCode, "countryName": countryName };
        pageRoot.currentLocale = newLocale;
    }

    function _copy(object) {
        var copy = {};
        for (var key in object)
            copy[key] = object[key];
        return copy;
    }

    /*
     * Keyboards are written straight through: adding one takes effect the next
     * time the keyboard comes up, so there is nothing to hold back.
     */
    function addKeyboard(languageCode) {
        if (enabledKeyboards.indexOf(languageCode) >= 0)
            return;

        var keyboards = enabledKeyboards.slice();
        keyboards.push(languageCode);
        _writeKeyboards(keyboards, activeKeyboard !== "" ? activeKeyboard : languageCode);
    }

    function removeKeyboard(languageCode) {
        var keyboards = enabledKeyboards.slice();
        var at = keyboards.indexOf(languageCode);
        if (at < 0)
            return;

        keyboards.splice(at, 1);

        // Removing the default leaves the first of the rest as the default,
        // rather than a keyboard preference pointing at nothing.
        var active = activeKeyboard;
        if (active === languageCode)
            active = keyboards.length > 0 ? keyboards[0] : "";

        _writeKeyboards(keyboards, active);
    }

    // A keyboard's switch. The last one on stays on (its switch is disabled too).
    function setKeyboardEnabled(languageCode, on) {
        if (on) {
            addKeyboard(languageCode);
            return;
        }
        if (enabledKeyboards.length === 1 && enabledKeyboards[0] === languageCode)
            return;
        removeKeyboard(languageCode);
    }

    function setActiveKeyboard(languageCode) {
        _writeKeyboards(enabledKeyboards, languageCode);
    }

    function _writeKeyboards(keyboards, active) {
        pageRoot.enabledKeyboards = keyboards;
        pageRoot.activeKeyboard = active;

        var keyboard = _copy(keyboardPrefs);
        keyboard.enabledLanguages = keyboards;
        if (active !== "")
            keyboard.activeLanguage = active;
        pageRoot.keyboardPrefs = keyboard;

        _setPreferences({"keyboard": keyboard});
    }

    /*
     * Bindings with LuneOS settings
     */
    function retrieveProperties() {

        luna.call("luna://com.webos.service.systemservice/getPreferenceValues",
                  JSON.stringify({"key": "locale"}),
                  _handleGetLocales, _handleGetError);

        luna.call("luna://com.webos.service.systemservice/getPreferenceValues",
                  JSON.stringify({"key": "region"}),
                  _handleGetRegions, _handleGetError);
    }

    function _handleGetPreferences(response) {
        if (response.hasOwnProperty("locale") && response.locale) {
            pageRoot.currentLocale = response.locale;
            // Only the first read is the baseline: later ones are our own
            // writes coming back, and would make the Apply button vanish
            // before it was pressed.
            if (!pageRoot.prefsLoaded)
                pageRoot.originalLocale = response.locale;
        }
        if (response.hasOwnProperty("region") && response.region) {
            pageRoot.region = response.region;
            if (!pageRoot.prefsLoaded)
                pageRoot.originalRegion = response.region;
        }
        if (response.hasOwnProperty("keyboard")) {
            var keyboardValue = response.keyboard;
            // Written as an object, but a JSON string is what the old apps
            // left behind, so take either.
            if (typeof keyboardValue === "string") {
                try {
                    keyboardValue = JSON.parse(keyboardValue);
                } catch (e) {
                    console.warn("Cannot parse the keyboard preferences: " + e);
                    keyboardValue = {};
                }
            }
            pageRoot.keyboardPrefs = keyboardValue || {};
            // "pinyin", which this page used to write, is read as "zh": the
            // keyboard only ever saw its first two letters. It is written back
            // as "zh" with the next change.
            function twoLetter(code) { return code === "pinyin" ? "zh" : code; }
            if (pageRoot.keyboardPrefs.hasOwnProperty("enabledLanguages"))
                pageRoot.enabledKeyboards = pageRoot.keyboardPrefs.enabledLanguages.map(twoLetter);
            if (pageRoot.keyboardPrefs.hasOwnProperty("activeLanguage"))
                pageRoot.activeKeyboard = twoLetter(pageRoot.keyboardPrefs.activeLanguage);
        }
    }

    function _handleGetLocales(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (response.hasOwnProperty("locale"))
            pageRoot.availableLocales = response.locale;
    }

    function _handleGetRegions(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (response.hasOwnProperty("region"))
            pageRoot.availableRegions = response.region;
    }

    // Push changes to LuneOS
    // SystemPreferences refuses to write before the first read
    function _setPreferences(params) {
        prefs.setMany(params);
    }

    function applyChanges() {
        _setPreferences({"locale": pageRoot.currentLocale, "region": pageRoot.region});

        pageRoot.originalLocale = pageRoot.currentLocale;
        pageRoot.originalRegion = pageRoot.region;
    }

    function restartDevice() {
        luna.call("luna://com.webos.service.sleep/shutdown/machineReboot",
                  JSON.stringify({"reason": "Regional settings changed"}),
                  _handleSetSuccess, _handleSetError);
    }
}
