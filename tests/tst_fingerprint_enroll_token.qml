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
import QtQuick.Controls.LuneOS
import QtTest

import "../src/qml/General"

/*
 * One passcode for several fingers on the Fingerprint page: the token
 * luna-authmanager gives for a right passcode is kept and reused for the
 * next finger while its enrollLifetime runs, and asked for again once it is
 * over, refused, or never had one (an older luna-authmanager). The page's
 * replies are fed to it directly: luneos-components' LunaService stand-in
 * does not answer com.webos.service.auth or the fingerprint service's
 * enroll, so whether the page started an enrolment (enrolling) or went to
 * ask for the passcode (it did not) is what is checked. Run with
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
        FingerprintPage { anchors.fill: parent }
    }

    TestCase {
        name: "FingerprintEnrollToken"
        when: windowShown

        property var page: null

        function init() {
            page = createTemporaryObject(pageComponent, root);
            verify(page !== null, "the page did not load");
        }

        function reply(fields) {
            return { "payload": JSON.stringify(fields) };
        }

        // The passcode was right: the first finger starts.
        function passcodeAccepted(fields) {
            page._verifiedForEnroll(reply(fields));
            verify(page.enrolling, "the first finger did not start");
        }

        function fingerAdded() {
            page.onEnrollMessage(reply({ "returnValue": true, "finished": true }));
            verify(!page.enrolling);
            compare(page.enrollResult, "Fingerprint added.");
        }

        function test_theNextFingerTakesNoPasscode() {
            passcodeAccepted({ "returnValue": true, "unlockToken": "t1",
                               "tokenLifetime": 30, "enrollLifetime": 600 });
            fingerAdded();

            page.askPasscodeThenEnroll();
            verify(page.enrolling, "the second finger asked for the passcode again");
            compare(page._enrollToken, "t1");
        }

        function test_anOverWindowAsksAgain() {
            passcodeAccepted({ "returnValue": true, "unlockToken": "t1",
                               "tokenLifetime": 30, "enrollLifetime": 600 });
            fingerAdded();

            page._enrollTokenUntil = Date.now() - 1;
            page.askPasscodeThenEnroll();
            verify(!page.enrolling, "a token past its window was used");
            compare(page._enrollToken, "");
        }

        function test_withoutAnEnrollLifetimeEveryFingerAsks() {
            passcodeAccepted({ "returnValue": true, "unlockToken": "t1", "tokenLifetime": 30 });
            fingerAdded();

            page.askPasscodeThenEnroll();
            verify(!page.enrolling, "a token without an enrollLifetime was used twice");
        }

        function test_aRefusedTokenIsForgotten() {
            passcodeAccepted({ "returnValue": true, "unlockToken": "t1",
                               "tokenLifetime": 30, "enrollLifetime": 600 });
            page.onEnrollMessage(reply({ "returnValue": false,
                                         "errorText": "Enrolling a finger takes the passcode" }));
            verify(!page.enrolling);
            compare(page._enrollToken, "");

            page.askPasscodeThenEnroll();
            verify(!page.enrolling, "a refused token was used again");
        }

        // A finger that fails part way (a bad scan, a full sensor) keeps it.
        function test_aFailedFingerKeepsTheToken() {
            passcodeAccepted({ "returnValue": true, "unlockToken": "t1",
                               "tokenLifetime": 30, "enrollLifetime": 600 });
            page.onEnrollMessage(reply({ "returnValue": true, "finished": true,
                                         "errorText": "FPERROR_TIMEOUT" }));
            verify(!page.enrolling);

            page.askPasscodeThenEnroll();
            verify(page.enrolling, "a finger that failed part way asked for the passcode");
        }
    }
}
