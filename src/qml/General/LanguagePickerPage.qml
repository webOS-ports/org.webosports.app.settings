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

// Theme specific properties
import QtQuick.Controls.LuneOS 2.0
// Units & font sizes
import LunaNext.Common 0.1

import "../Common"
import "../Common/LanguageNames.js" as LanguageNames

/*
 * Regional Settings, after the webOS 3.0.5 app of the same name
 * (com.palm.app.languagepicker, its regionalsettings scene).
 *
 * Same rows in the same order as the original: the display language, the list
 * of keyboards with an Add row under it, the region used for phone numbers,
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

    property bool prefsLoaded: false

    // The languages the shipped keyboard has plugins for. There is no call
    // that enumerates them, so this is the plugin set webos-keyboard builds.
    readonly property var keyboardLanguageCodes: [
        "ar", "cs", "da", "de", "en", "es", "fi", "fr", "he",
        "hu", "it", "nl", "pinyin", "pl", "pt", "ru", "sv"
    ]

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
         * Keyboards. The original let you swipe one away and tap Add to get
         * another; the same two things are here, with the one marked Default
         * being the keyboard that comes up first.
         */
        GroupBox {
            width: parent.width
            title: "Keyboards"

            Column {
                width: parent.width

                Repeater {
                    model: pageRoot.enabledKeyboards

                    delegate: Column {
                        width: parent.width

                        SwipeRow {
                            text: LanguageNames.nameForCode(modelData)

                            LuneOSSwipeDelegate.confirmText: "Remove Keyboard"
                            LuneOSSwipeDelegate.onConfirmed: pageRoot.removeKeyboard(modelData)

                            // Tapping the row makes it the one the keyboard
                            // starts in, which is what activeLanguage is.
                            onClicked: pageRoot.setActiveKeyboard(modelData)

                            Label {
                                anchors.right: parent.right
                                anchors.rightMargin: Units.gu(1)
                                anchors.verticalCenter: parent.verticalCenter
                                visible: modelData === pageRoot.activeKeyboard
                                text: "Default"
                                color: "#666666"
                                font.pixelSize: FontUtils.sizeToPixels("small")
                            }
                        }

                        HorizontalSeparator {
                            width: parent.width
                        }
                    }
                }

                Label {
                    width: parent.width
                    visible: pageRoot.enabledKeyboards.length === 0
                    height: visible ? Units.gu(6) : 0
                    verticalAlignment: Text.AlignVCenter
                    text: "No keyboard is set up."
                    color: "#666666"
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }

                ItemDelegate {
                    width: parent.width
                    height: Units.gu(6)
                    text: "Add..."
                    font.pixelSize: FontUtils.sizeToPixels("16pt")

                    onClicked: {
                        keyboardPicker.entries = pageRoot.keyboardEntries();
                        keyboardPicker.open();
                    }
                }
            }
        }

        ExplanationText {
            text: "Swipe a keyboard sideways to remove it. Tap one to make it " +
                  "the keyboard that comes up first."
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
        id: keyboardPicker
        title: "Add a Keyboard"
        emptyText: "Every available keyboard is already set up."

        onPicked: (key, entry) => pageRoot.addKeyboard(key)
    }

    Dialog {
        id: applyDialog

        modal: true
        width: Math.min(parent.width - Units.gu(4), Units.gu(40))
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

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

        footer: Row {
            spacing: Units.gu(1)
            padding: Units.gu(1)

            Button {
                text: "Cancel"
                LuneOSButton.mainColor: LuneOSButton.secondaryColor
                onClicked: applyDialog.close()
            }
            Button {
                // Writing the preferences without restarting is worth having
                // on its own: a newly started app already picks them up.
                text: "Apply Only"
                onClicked: {
                    pageRoot.applyChanges();
                    applyDialog.close();
                }
            }
            Button {
                text: "Apply and Restart"
                LuneOSButton.mainColor: LuneOSButton.negativeColor
                LuneOSButton.textColor: "white"
                onClicked: {
                    pageRoot.applyChanges();
                    pageRoot.restartDevice();
                    applyDialog.close();
                }
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

    function keyboardEntries() {
        var entries = [];
        for (var i = 0; i < keyboardLanguageCodes.length; i++) {
            var code = keyboardLanguageCodes[i];
            if (enabledKeyboards.indexOf(code) >= 0)
                continue;

            entries.push({
                "key": code,
                // "pinyin" is a way of typing Chinese, not a language code,
                // so it would come out of the table unchanged.
                "label": code === "pinyin" ? "Chinese (Pinyin)"
                                           : LanguageNames.nameForCode(code)
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

    function setActiveKeyboard(languageCode) {
        _writeKeyboards(enabledKeyboards, languageCode);
    }

    function _writeKeyboards(keyboards, active) {
        pageRoot.enabledKeyboards = keyboards;
        pageRoot.activeKeyboard = active;

        var prefs = _copy(keyboardPrefs);
        prefs.enabledLanguages = keyboards;
        if (active !== "")
            prefs.activeLanguage = active;
        pageRoot.keyboardPrefs = prefs;

        _setPreferences({"keyboard": prefs});
    }

    /*
     * Bindings with LuneOS settings
     */
    function retrieveProperties() {
        luna.subscribe("luna://com.webos.service.systemservice/getPreferences",
                       JSON.stringify({"keys": ["locale", "region", "keyboard"],
                                       "subscribe": true}),
                       _handleGetPreferences, _handleGetError);

        luna.call("luna://com.webos.service.systemservice/getPreferenceValues",
                  JSON.stringify({"key": "locale"}),
                  _handleGetLocales, _handleGetError);

        luna.call("luna://com.webos.service.systemservice/getPreferenceValues",
                  JSON.stringify({"key": "region"}),
                  _handleGetRegions, _handleGetError);
    }

    function _handleGetPreferences(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);

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
            if (pageRoot.keyboardPrefs.hasOwnProperty("enabledLanguages"))
                pageRoot.enabledKeyboards = pageRoot.keyboardPrefs.enabledLanguages;
            if (pageRoot.keyboardPrefs.hasOwnProperty("activeLanguage"))
                pageRoot.activeKeyboard = pageRoot.keyboardPrefs.activeLanguage;
        }

        pageRoot.prefsLoaded = true;
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
    function _setPreferences(params) {
        if (!pageRoot.prefsLoaded) {
            console.log("Trying to set preferences before reading them first: ignoring.");
            return;
        }

        luna.call("luna://com.webos.service.systemservice/setPreferences", JSON.stringify(params),
                  _handleSetSuccess, _handleSetError);
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
