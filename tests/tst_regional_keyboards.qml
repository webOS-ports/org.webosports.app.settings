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

import QtQuick
import QtTest

import "../src/qml/General"

/*
 * Regional Settings' Keyboards group: a switch for every keyboard installed,
 * writing the keyboard preference's enabledLanguages, and the Default picker
 * for its activeLanguage. Against luneos-components' stand-ins; run with
 * tests/run-tests.sh.
 */
Item {
    id: root
    width: 480
    height: 800

    // What the category window gives its pages.
    property string appId: "org.webosports.app.settings"
    property Component actionHeaderComponent

    Component {
        id: pageComponent
        LanguagePickerPage { anchors.fill: parent }
    }

    TestCase {
        name: "RegionalKeyboards"
        when: windowShown

        function findByText(item, text) {
            if (item.text === text && item.visible)
                return item;
            for (var i = 0; i < item.children.length; ++i) {
                var found = findByText(item.children[i], text);
                if (found)
                    return found;
            }
            return null;
        }

        // The switch row for [label]: a LabelAndSwitch is a Switch, which has "checked"
        // (the Language row above shows "English" too).
        function findSwitch(item, label) {
            if (item.text === label && item.visible && item.hasOwnProperty("checked"))
                return item;
            for (var i = 0; i < item.children.length; ++i) {
                var found = findSwitch(item.children[i], label);
                if (found)
                    return found;
            }
            return null;
        }

        function switchFor(item, label) {
            var row = findSwitch(item, label);
            verify(row !== null, "no switch for " + label);
            return row;
        }

        // A page with three keyboards installed, English and German on, German the default.
        // keyboardPrefs is the keyboard preference as the page last wrote it.
        function page() {
            var p = createTemporaryObject(pageComponent, root);
            verify(p !== null, "the page did not load");
            p._installedKeyboards = ["de", "en", "fr"];
            p._handleGetPreferences({ "keyboard": { "enabledLanguages": ["en", "de"], "activeLanguage": "de",
                                                    "pre": { "style": "white" } } });
            return p;
        }

        function test_a_switch_for_every_installed_keyboard() {
            var p = page();
            compare(JSON.stringify(p.keyboardRows), JSON.stringify(["en", "fr", "de"]), "by name: English, French, German");
            compare(switchFor(p, "English").checked, true);
            compare(switchFor(p, "German").checked, true);
            compare(switchFor(p, "French").checked, false);
            compare(findByText(p, "Add..."), null, "the switches are the way to add one");
        }

        function test_turning_one_on_and_off() {
            var p = page();
            p.setKeyboardEnabled("fr", true);
            compare(JSON.stringify(p.enabledKeyboards), JSON.stringify(["en", "de", "fr"]), "added at the end");
            var kb = p.keyboardPrefs;
            compare(JSON.stringify(kb.enabledLanguages), JSON.stringify(["en", "de", "fr"]));
            compare(kb.activeLanguage, "de", "the default kept");
            compare(kb.pre.style, "white", "the rest of the keyboard preference kept");
            compare(switchFor(p, "French").checked, true);

            p.setKeyboardEnabled("en", false);
            compare(JSON.stringify(p.enabledKeyboards), JSON.stringify(["de", "fr"]));
            compare(switchFor(p, "English").checked, false);
        }

        function test_turning_off_the_default() {
            var p = page();
            p.setKeyboardEnabled("de", false);
            compare(JSON.stringify(p.enabledKeyboards), JSON.stringify(["en"]));
            compare(p.activeKeyboard, "en", "the first of the rest is the default");
        }

        function test_the_last_one_stays_on() {
            var p = page();
            p.setKeyboardEnabled("en", false);
            verify(!switchFor(p, "German").enabled, "the last one's switch can be used");
            p.setKeyboardEnabled("de", false);
            compare(JSON.stringify(p.enabledKeyboards), JSON.stringify(["de"]));
            compare(JSON.stringify(p.keyboardPrefs.enabledLanguages), JSON.stringify(["de"]), "the last one written away");
            verify(switchFor(p, "French").enabled, "an off switch disabled");
        }

        function test_an_enabled_keyboard_not_installed_can_be_turned_off() {
            var p = page();
            p._handleGetPreferences({ "keyboard": { "enabledLanguages": ["en", "pinyin"], "activeLanguage": "en" } });
            verify(p.keyboardRows.indexOf("zh") >= 0, "Chinese, enabled as pinyin, has no row");
            compare(switchFor(p, "Chinese (Pinyin)").checked, true);
            p.setKeyboardEnabled("zh", false);
            compare(JSON.stringify(p.enabledKeyboards), JSON.stringify(["en"]));
        }

        function test_default_picker() {
            var p = page();
            verify(findByText(p, "Default") !== null, "no Default row");
            compare(JSON.stringify(p.defaultKeyboardEntries().map(function (e) { return e.key; })),
                    JSON.stringify(["en", "de"]), "only the keyboards that are on, by name");
            p.setActiveKeyboard("en");
            compare(p.keyboardPrefs.activeLanguage, "en");
        }

        // A switch toggled by hand follows the preference again when it changes elsewhere.
        function test_switch_follows_the_preference_after_a_toggle() {
            var p = page();
            var fr = switchFor(p, "French");
            fr.toggle();
            fr.toggled();
            compare(fr.checked, true);
            p._handleGetPreferences({ "keyboard": { "enabledLanguages": ["en"], "activeLanguage": "en" } });
            compare(fr.checked, false, "French still on after the keyboard turned it off");
            compare(switchFor(p, "German").checked, false);
        }
    }
}
