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
import LuneOS.Service 1.0

import "../src/qml/General"

/*
 * Settings > Buttons against a device key file from data/ and a tweaks
 * service that keeps what it is given. Run with tests/run-tests.sh.
 */
Item {
    id: root
    width: 480
    height: 800

    // What the category window gives its pages.
    property string appId: "org.webosports.app.settings"
    property Component actionHeaderComponent

    // The shell's HardwareKeys.knownActions (luna-next-cardshell). Whatever the
    // page offers must be in it, or the shell ignores the choice.
    readonly property var shellActions: [
        "call.answer", "call.hangup", "shell.launcher", "shell.back",
        "audio.mute", "display.sleep", "media.headset", "media.play",
        "media.pause", "media.stop", "media.next", "media.previous",
        "app.camera", "torch.toggle", "none"
    ]

    Component {
        id: serviceComponent
        LunaService {
            property string stored: ""
            property bool down: false
            property var apps: []
            property var sets: []

            function call(uri, args, ok, err) {
                if (uri === "luna://org.webosports.service.tweaks.prefs/get") {
                    if (down) {
                        err("Service does not exist");
                        return;
                    }
                    ok({ "payload": JSON.stringify({ "returnValue": true,
                                                     "hardwareKeyActions": stored }) });
                } else if (uri === "luna://org.webosports.service.tweaks.prefs/set") {
                    var params = JSON.parse(args);
                    sets.push(params);
                    stored = params.hardwareKeyActions;
                    ok({ "payload": JSON.stringify({ "returnValue": true }) });
                }
            }
            function subscribe(uri, args, ok, err) {
                if (uri === "luna://com.webos.service.applicationManager/listApps")
                    ok({ "payload": JSON.stringify({ "returnValue": true, "apps": apps }) });
            }
        }
    }

    Component {
        id: pageComponent
        ButtonsPage { anchors.fill: parent }
    }

    function dataPath(name) {
        return Qt.resolvedUrl("data/" + name).toString().replace(/^file:\/\//, "");
    }

    TestCase {
        name: "ButtonsPage"
        when: windowShown

        property var service: null

        function makePage(file, stored, extra) {
            service = createTemporaryObject(serviceComponent, root);
            service.stored = stored || "";
            if (extra && extra.down)
                service.down = true;
            if (extra && extra.apps)
                service.apps = extra.apps;
            var page = createTemporaryObject(pageComponent, root,
                                             { "luna": service, "deviceFile": dataPath(file) });
            verify(page !== null, "the page did not load");
            return page;
        }

        function keyBox(page, name) {
            return findChild(page, "key_" + name);
        }

        function row(page, name, slot) {
            var box = keyBox(page, name);
            verify(box !== null, "no group for " + name);
            return findChild(box, slot);
        }

        function test_onlyTheLabelledKeysAreListed() {
            var page = makePage("hardware-keys-buttons.json");
            compare(page.keys.length, 2);
            compare(page.keys[0].name, "Key_Launch2");
            compare(page.keys[0].label, "Assistant button");
            compare(page.keys[1].name, "Key_Launch1");
            tryVerify(function () { return keyBox(page, "Key_Launch2") !== null; });
            verify(keyBox(page, "Key_Launch1") !== null);
            // Set by the device but not offered: the user cannot change them.
            compare(keyBox(page, "Key_Camera"), null);
            compare(keyBox(page, "Key_Menu"), null);
            compare(keyBox(page, "Key_HomePage"), null);
            verify(!findChild(page, "noButtons").visible);
        }

        function test_aDeviceWithoutTheFileHasNothingToSetUp() {
            var page = makePage("no-such-file.json");
            compare(page.keys.length, 0);
            verify(findChild(page, "noButtons").visible);
        }

        function test_aBrokenFileHasNothingToSetUp() {
            ignoreWarning(new RegExp("ButtonsPage: cannot parse"));
            var page = makePage("hardware-keys-broken.json");
            compare(page.keys.length, 0);
            verify(findChild(page, "noButtons").visible);
        }

        function test_theDevicesActionsShowUntilTheUserChooses() {
            var page = makePage("hardware-keys-buttons.json");
            compare(page.actionFor("Key_Launch2", "press"), "none");
            compare(page.actionFor("Key_Launch2", "hold"), "app.camera");
            compare(row(page, "Key_Launch2", "press").value, "Nothing");
            compare(row(page, "Key_Launch2", "hold").value, "Open Camera");
            // An empty press from the generator is no action, not an unknown one.
            compare(page.actionFor("Key_Launch1", "press"), "none");
        }

        function test_theUsersChoiceIsShown() {
            var page = makePage("hardware-keys-buttons.json",
                                JSON.stringify({ "Key_Launch2": { "press": "torch.toggle" } }));
            compare(row(page, "Key_Launch2", "press").value, "Torch on or off");
            // Not chosen: still the device's.
            compare(row(page, "Key_Launch2", "hold").value, "Open Camera");
        }

        function test_aChoiceTheShellWouldIgnoreIsNotShownAsInForce() {
            var page = makePage("hardware-keys-buttons.json",
                                JSON.stringify({ "Key_Launch2": { "press": "rm -rf /",
                                                                  "hold": "app.launch:../x" } }));
            compare(page.actionFor("Key_Launch2", "press"), "none");
            compare(page.actionFor("Key_Launch2", "hold"), "app.camera");
        }

        function test_anUnreadableTweakIsNoChoice() {
            ignoreWarning(new RegExp("ButtonsPage: cannot parse the hardwareKeyActions tweak"));
            var page = makePage("hardware-keys-buttons.json", "{not json");
            compare(JSON.stringify(page.choices), "{}");
            compare(page.actionFor("Key_Launch2", "hold"), "app.camera");
        }

        function test_choosingWritesTheTweak() {
            var page = makePage("hardware-keys-buttons.json",
                                JSON.stringify({ "Key_Launch1": { "press": "audio.mute" } }));
            var picker = findChild(page, "actionPicker");
            picker.openFor("Key_Launch2", "hold", "Assistant button: press and hold");
            picker.picked("torch.toggle", {});
            compare(service.sets.length, 1);
            compare(service.sets[0].owner, "luna-next-cardshell");
            var written = JSON.parse(service.sets[0].hardwareKeyActions);
            compare(written.Key_Launch2.hold, "torch.toggle");
            compare(written.Key_Launch2.press, undefined);
            // The other key's choice is kept.
            compare(written.Key_Launch1.press, "audio.mute");
            compare(row(page, "Key_Launch2", "hold").value, "Torch on or off");
        }

        function test_anActionTheShellDoesNotKnowIsNotWritten() {
            var page = makePage("hardware-keys-buttons.json");
            page.setChoice("Key_Launch2", "press", "shell.reboot");
            compare(service.sets.length, 0);
        }

        function test_everyOfferedActionIsOneTheShellKnows() {
            var page = makePage("hardware-keys-buttons.json");
            for (var i = 0; i < page.actionChoices.length; i++)
                verify(root.shellActions.indexOf(page.actionChoices[i].key) >= 0,
                       page.actionChoices[i].key + " is not a shell action");
        }

        function test_installedAppsCanBeChosen() {
            var page = makePage("hardware-keys-buttons.json", "",
                                { "apps": [ { "id": "org.webosports.app.memos", "title": "Memos" },
                                            { "id": "org.webosports.app.hidden", "title": "Hidden",
                                              "visible": false },
                                            { "id": "bad id; rm", "title": "Bad" },
                                            { "id": "org.webosports.app.calculator",
                                              "title": "Calculator" } ] });
            var keys = page.pickerEntries.map(function (e) { return e.key; });
            var calc = keys.indexOf("app.launch:org.webosports.app.calculator");
            var memos = keys.indexOf("app.launch:org.webosports.app.memos");
            verify(calc > 0 && memos > calc, "apps are listed after the actions, by title");
            compare(keys.indexOf("app.launch:org.webosports.app.hidden"), -1);
            compare(keys.length, page.actionChoices.length + 2);
            compare(page.pickerEntries[memos].label, "Open Memos");

            page.setChoice("Key_Launch2", "press", "app.launch:org.webosports.app.memos");
            compare(row(page, "Key_Launch2", "press").value, "Open Memos");
            compare(JSON.parse(service.stored).Key_Launch2.press,
                    "app.launch:org.webosports.app.memos");
        }

        function test_withoutTheTweaksServiceNothingCanBeChanged() {
            ignoreWarning(new RegExp("Tweaks service did not answer"));
            var page = makePage("hardware-keys-buttons.json", "", { "down": true });
            verify(!page.tweaksAvailable);
            compare(keyBox(page, "Key_Launch2"), null);
            verify(!findChild(page, "noButtons").visible);
        }
    }
}
