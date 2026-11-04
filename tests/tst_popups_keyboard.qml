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

import "../src/qml/Connectivity"
import "../src/qml/General"

/*
 * Popups with a text field and the on-screen keyboard, on a 480x800 phone
 * with the keys over the lower 45%: the Wi-Fi password popup (centred above
 * them by the LuneOS style) and the dictionary (which can be as tall as the
 * window, and caps itself at the keys). Needs the luneos-components whose
 * style Popup has keyboardTop. Run with tests/run-tests.sh.
 */
Item {
    id: root
    width: 480
    height: 800

    Component {
        id: passphraseComponent
        WiFiProvidePassphrasePopup {
            serviceName: "Home"
            requestedFields: ({ "Passphrase": {} })
        }
    }

    Component {
        id: dictionaryComponent
        DictionaryPopup {
            words: [{ _id: "1", word: "LuneOS" }]
            shortcuts: [{ _id: "2", shortcut: "brb", substitution: "be right back" }]
        }
    }

    TestCase {
        name: "PopupsKeyboard"
        when: windowShown

        readonly property real keys: 360

        function showWithKeyboard(component) {
            var popup = createTemporaryObject(component, root);
            verify(popup !== null, "the popup did not load");
            popup._keyboard.heightForTest = keys;
            popup.open();
            tryVerify(function() { return popup.opened; });
            return popup;
        }

        function test_passphrase_above_keyboard() {
            var popup = showWithKeyboard(passphraseComponent);
            var top = popup.parent.height - keys;
            compare(popup.keyboardTop, top);
            verify(popup.y >= 0);
            verify(popup.y + popup.height <= top,
                   "the popup ends at " + (popup.y + popup.height) + ", the keys start at " + top);
        }

        function test_dictionary_capped_at_keyboard() {
            var popup = showWithKeyboard(dictionaryComponent);
            var top = popup.parent.height - keys;
            verify(popup.y >= 0);
            verify(popup.y + popup.height <= top,
                   "the popup ends at " + (popup.y + popup.height) + ", the keys start at " + top);
            // The keyboard gone, it is as tall as it was.
            popup._keyboard.heightForTest = 0;
            verify(popup.y + popup.height > top, "taller again without the keyboard");
        }
    }
}
