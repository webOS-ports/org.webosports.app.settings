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

import LunaNext.Common 0.1

/*
 * Every settings page as the device opens it: GenericCategoryWindow with the
 * page's appId (each category is its own application there), at the size of
 * the screen this run pretends to be - tests/run-tests.sh runs it once per
 * profile in PROFILES. luneos-components' test/imports stand in for the
 * services the pages call. Each page is checked for the basics a layout
 * break shows up as - the header and the page are there, have a size and sit
 * inside the window, and the page's own scroll area does not run wider than
 * the window - and saved as build/test-output/ui/<profile>-<page>.png to look
 * at.
 */
TestCase {
    id: test
    name: "Screens"
    when: windowShown

    readonly property string shotDir: decodeURIComponent(Qt.resolvedUrl("../../build/test-output/ui").toString()
                                                         .replace(/^file:\/\//, ""))
    readonly property url windowUrl: Qt.resolvedUrl("../../src/qml/GenericCategoryWindow.qml")
    property var app: null

    function makeWindow(appId) {
        var component = Qt.createComponent(windowUrl);
        if (component.status === Component.Error)
            fail(component.errorString());
        var window = component.createObject(null, { appId: appId, launchParams: "{}" });
        verify(window !== null, "the window for " + appId + " was not made");
        return window;
    }

    // One row per page the category window knows, by its appId; the short
    // name ("org.webosports.app.settings.wifi" -> "wifi") names the picture.
    function test_page_data() {
        var window = makeWindow("org.webosports.app.settings.example");
        var rows = [];
        for (var appId in window.categories)
            rows.push({ tag: appId.replace(/^org\.webosports\.app\.settings\./, ""), appId: appId });
        window.destroy();
        return rows;
    }

    function cleanup() {
        if (app) {
            app.destroy();
            app = null;
        }
        wait(20);
    }

    function shot(name) {
        var done = false;
        verify(app.contentItem.grabToImage(function(result) {
            result.saveToFile(shotDir + "/" + Settings.profileName + "-" + name + ".png");
            done = true;
        }), "grab " + name);
        tryVerify(function() { return done; }, 5000, "saved " + name);
    }

    // The item's rectangle in the window.
    function inWindow(item) {
        return item.mapToItem(app.contentItem, 0, 0, item.width, item.height);
    }

    function verifyInside(item, what) {
        verify(item.visible, what + " is not visible");
        verify(item.width > 0 && item.height > 0, what + " has no size (" + item.width + "x" + item.height + ")");
        var r = inWindow(item);
        verify(r.x >= -0.5 && r.y >= -0.5 && r.x + r.width <= app.width + 0.5 && r.y + r.height <= app.height + 0.5,
               what + " is not inside the " + app.width + "x" + app.height + " window: "
               + r.x + "," + r.y + " " + r.width + "x" + r.height);
    }

    // The page's scroll areas that fill (most of) its width: those scroll
    // up and down, and anything wider than they are is cut off at the edge.
    // Narrower ones (a row of pictures, a picker) may well scroll sideways.
    function pageFlickables(item, page, out) {
        if (!item || !item.visible)
            return out;
        if (item.flickableDirection !== undefined && item.contentWidth !== undefined
                && item.width >= page.width * 0.8)
            out.push(item);
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++)
            pageFlickables(kids[i], page, out);
        return out;
    }

    function test_page(data) {
        app = makeWindow(data.appId);
        app.requestActivate();
        compare(app.width, Settings.displayWidth);
        compare(app.height, Settings.displayHeight);
        var loader = app._categoryLoader;
        tryCompare(loader, "status", Loader.Ready, 5000, data.tag + " did not load");
        var page = loader.item;
        verify(page !== null);
        // Service replies from the stand-ins, lists filling and the style's
        // transitions come on their own time.
        wait(400);
        waitForItemPolished(page);
        // The picture first, so a page that fails below can still be seen.
        shot(data.tag);

        verifyInside(loader, data.tag + "'s page area");
        verifyInside(page, data.tag + "'s page");
        var header = null;
        for (var k = 0; k < app.contentItem.children.length; k++)
            if (app.contentItem.children[k].title === app.categoryTitle)
                header = app.contentItem.children[k];
        verify(header !== null, data.tag + ": no header");
        verifyInside(header, data.tag + "'s header");
        verify(loader.y >= header.y + header.height - 0.5, data.tag + ": the page starts under the header");

        var flicks = pageFlickables(page, page, []);
        for (var i = 0; i < flicks.length; i++) {
            var f = flicks[i];
            if (f.flickableDirection === Flickable.HorizontalFlick
                    || (f.orientation !== undefined && f.orientation === ListView.Horizontal))
                continue;
            verify(f.contentWidth <= f.width + 1,
                   data.tag + ": a scroll area (" + f + " in " + f.parent + ") is wider inside (" + f.contentWidth + ") than it is (" + f.width + ")");
        }
    }
}
