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
 * Text Assist's Pre Keyboard group: the vibration strength under Vibrate on
 * Keys, and the words deleted from the keys' bar with Put Back. Against
 * luneos-components' stand-ins; run with tests/run-tests.sh.
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
        TextAssistPage { anchors.fill: parent }
    }

    TestCase {
        name: "TextAssistPre"
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

        function page() {
            var p = createTemporaryObject(pageComponent, root);
            verify(p !== null, "the page did not load");
            // The settings write the whole keyboard preference; keep what they write here.
            p.setKeyboardPreference = function (key, value) { p.keyboardPrefs[key] = value; };
            return p;
        }

        function test_vibration_strength_index() {
            var p = page();
            p.pre = {};
            compare(p.preLevel(), 0, "unset is Light");
            p.pre = { "vibrateLevel": 2 };
            compare(p.preLevel(), 1);
            p.pre = { "vibrateLevel": 3 };
            compare(p.preLevel(), 2);
            p.pre = { "vibrateLevel": 9 };
            compare(p.preLevel(), 2, "held to Strong");
            p.pre = { "vibrateLevel": "loud" };
            compare(p.preLevel(), 0, "not a number is Light");
        }

        function test_strength_shown_only_while_vibrating() {
            var p = page();
            p.phone = true;
            p.pre = { "vibrate": false };
            compare(findByText(p, "Vibration Strength"), null);
            p.pre = { "vibrate": true, "vibrateLevel": 2 };
            verify(findByText(p, "Vibration Strength") !== null, "no strength while vibrating");
        }

        function test_size_on_a_phone() {
            var p = page();
            p.phone = true;
            verify(findByText(p, "Size") !== null, "no Size on a phone: the Pre Keyboard's height");
            compare(findByText(p, "Layout"), null);
            compare(findByText(p, "Height"), null);
        }

        function test_emoji_suggestions_switch() {
            var p = page();
            p.phone = true;
            p.pre = {};
            verify(findByText(p, "Emoji Suggestions") !== null, "no Emoji Suggestions switch");
        }

        function test_deleted_words_listed_and_put_back() {
            var p = page();
            p.phone = true;
            p.pre = { "style": "white", "removed": { "en": ["yest", "om"], "de": ["Dom"] } };
            var listed = p.preDeletedWords();
            compare(listed.length, 3);
            compare(listed[0].language, "de");
            compare(listed[0].word, "Dom");
            compare(listed[1].word, "om", "a language's words in order");
            compare(listed[2].word, "yest");
            verify(findByText(p, "Deleted Words") !== null, "no Deleted Words with words deleted");

            p.putBackPreWord("en", "yest");
            compare(JSON.stringify(p.pre.removed), JSON.stringify({ "en": ["om"], "de": ["Dom"] }));
            compare(p.pre.style, "white", "the rest of the pre object kept");
            p.putBackPreWord("de", "Dom");
            verify(!p.pre.removed.hasOwnProperty("de"), "an empty language is dropped");
            p.putBackPreWord("en", "om");
            compare(p.preDeletedWords().length, 0);
            compare(findByText(p, "Deleted Words"), null);
        }
    }
}
