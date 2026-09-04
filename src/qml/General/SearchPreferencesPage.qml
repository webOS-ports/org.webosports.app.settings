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

/*
 * Just Type, after the webOS 3.0.5 app of the same name
 * (com.palm.app.searchpreferences).
 *
 * Same page as the original: what may turn up in Just Type results, which
 * search engine the "search the web" row uses, and then three lists - Content,
 * Search Using and Actions - each with a switch that turns the whole list on
 * or off and a checkbox per entry.
 *
 * The original's "Find More..." button is gone with the App Catalog it opened.
 *
 * Where this stands on LuneOS: the card shell has a Just Type field and hands
 * typing to the launcher, but nothing on the device implements
 * com.palm.universalsearch, so there is no list of searchable things to
 * configure yet. The page is wired to the service the legacy app used and says
 * plainly when it cannot reach it, rather than offering switches that go
 * nowhere.
 *
 * The methods this page expects of com.palm.universalsearch:
 *   getAllSearchPreference {}
 *      -> { returnValue, SearchPreference: { AppSearch, ContactSearch, GAL,
 *           defaultSearch, defaultSearchEngine } }   (values are "true"/"false")
 *   getUniversalSearchList { subscribe }
 *      -> { returnValue, UniversalSearchList: [], DBSearchItemList: [],
 *           ActionList: [] }, each entry
 *           { id, displayName, iconFilePath, type, enabled }
 *   setSearchPreference   { key, value }
 *   updateSearchItem      { id, enabled, category, setDefault }
 *   updateAllSearchItems  { category, enabled }
 */
BasePage {
    id: pageRoot

    readonly property string searchService: "com.palm.universalsearch"

    property bool serviceAvailable: false

    property bool appSearch: true
    property bool contactSearch: true
    property bool galSearch: false
    // Whether the "search the web" row appears in Just Type at all
    property bool defaultSearch: true
    property string defaultSearchEngineId: ""
    // true only when the service actually reported a GAL preference: without
    // an Exchange account there is no global address list to look anything up
    // in, and the original hid the row for exactly that reason.
    property bool galSupported: false

    property var searchItems: []
    property var contentItems: []
    property var actionItems: []

    Component.onCompleted: retrieveProperties();

    readonly property var defaultSearchEngine: {
        for (var i = 0; i < searchItems.length; i++) {
            if (searchItems[i].id === defaultSearchEngineId)
                return searchItems[i];
        }
        return null;
    }

    // The three configurable lists, in the order the original showed them.
    readonly property var categories: [
        { "title": "Content",      "category": "dbsearch", "items": contentItems },
        { "title": "Search Using", "category": "search",   "items": searchItems  },
        { "title": "Actions",      "category": "action",   "items": actionItems  }
    ]

    function categoryHasAny(items) {
        for (var i = 0; i < items.length; i++) {
            if (items[i].enabled)
                return true;
        }
        return false;
    }

    SettingsPageContent {
        ServiceUnavailableNotice {
            visible: !pageRoot.serviceAvailable

            serviceName: pageRoot.searchService
            description: "Just Type has nothing to search until a universal " +
                         "search service keeps the list. The rows below show " +
                         "what would be configured."

            onRetry: pageRoot.retrieveProperties()
        }

        ExplanationText {
            text: "Select the items you would like to appear in your search results."
        }

        GroupBox {
            width: parent.width
            enabled: pageRoot.serviceAvailable

            title: "Search Results"
            Column {
                width: parent.width

                LabelAndSwitch {
                    id: appSearchSwitch
                    label: "Applications"

                    checked: pageRoot.appSearch
                    Connections {
                        target: pageRoot
                        function onAppSearchChanged() {
                            appSearchSwitch.checked = pageRoot.appSearch;
                        }
                    }
                    onToggled: pageRoot.setSearchPreference("AppSearch", checked)
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndSwitch {
                    id: contactSearchSwitch
                    label: "Contacts"

                    checked: pageRoot.contactSearch
                    Connections {
                        target: pageRoot
                        function onContactSearchChanged() {
                            contactSearchSwitch.checked = pageRoot.contactSearch;
                        }
                    }
                    onToggled: pageRoot.setSearchPreference("ContactSearch", checked)
                }

                HorizontalSeparator {
                    width: parent.width
                    visible: pageRoot.galSupported
                }

                LabelAndSwitch {
                    id: galSwitch
                    visible: pageRoot.galSupported
                    label: "Automatic Global Address Lookup"

                    checked: pageRoot.galSearch
                    Connections {
                        target: pageRoot
                        function onGalSearchChanged() {
                            galSwitch.checked = pageRoot.galSearch;
                        }
                    }
                    onToggled: pageRoot.setSearchPreference("GAL", checked)
                }
            }
        }

        GroupBox {
            width: parent.width
            enabled: pageRoot.serviceAvailable

            title: "Default Search Engine"
            Column {
                width: parent.width

                LabelAndSwitch {
                    id: defaultSearchSwitch
                    label: "Search the Web"

                    checked: pageRoot.defaultSearch
                    Connections {
                        target: pageRoot
                        function onDefaultSearchChanged() {
                            defaultSearchSwitch.checked = pageRoot.defaultSearch;
                        }
                    }
                    onToggled: pageRoot.setSearchPreference("defaultSearch", checked)
                }

                HorizontalSeparator {
                    width: parent.width
                    visible: pageRoot.defaultSearch
                }

                LabelAndPicker {
                    width: parent.width
                    visible: pageRoot.defaultSearch
                    label: "Engine"
                    value: pageRoot.defaultSearchEngine
                           ? pageRoot.defaultSearchEngine.displayName : ""
                    placeholder: "Pick a search engine"

                    onClicked: searchEnginePicker.open()
                }
            }
        }

        /*
         * Content / Search Using / Actions. Each group's own switch turns
         * every entry in it on or off in one call, which is what
         * updateAllSearchItems is for; the checkboxes below it move one entry
         * at a time.
         */
        Repeater {
            model: pageRoot.categories

            delegate: Column {
                id: categorySection

                readonly property var section: modelData

                width: parent.width
                spacing: Units.gu(2)
                visible: section.items.length > 0

                GroupBox {
                    width: parent.width
                    enabled: pageRoot.serviceAvailable

                    title: categorySection.section.title
                    Column {
                        width: parent.width

                        LabelAndSwitch {
                            label: "All"

                            checked: pageRoot.categoryHasAny(categorySection.section.items)
                            onToggled: pageRoot.setAllSearchItems(categorySection.section.category,
                                                                  checked)
                        }

                        Repeater {
                            model: categorySection.section.items

                            delegate: Column {
                                width: parent.width

                                HorizontalSeparator {
                                    width: parent.width
                                }

                                CheckBox {
                                    width: parent.width
                                    text: modelData.displayName
                                    checked: modelData.enabled
                                    LayoutMirroring.enabled: true
                                    font.pixelSize: FontUtils.sizeToPixels("16pt")
                                    font.weight: Font.Normal

                                    onToggled: pageRoot.setSearchItemEnabled(
                                                   categorySection.section.category,
                                                   modelData.id, checked)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /*
     * The engine list. Small enough that the original showed it as a second
     * scene with a Cancel button; a popup is the same thing on a page that has
     * no scene stack.
     */
    Popup {
        id: searchEnginePicker

        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        width: Math.min(parent.width - Units.gu(4), Units.gu(40))
        height: Math.min(parent.height - Units.gu(4), Units.gu(50))
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        ColumnLayout {
            anchors.fill: parent
            spacing: Units.gu(1)

            Label {
                Layout.fillWidth: true
                text: "Default Search Engine"
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: FontUtils.sizeToPixels("18pt")
                font.weight: Font.Bold
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                model: pageRoot.searchItems

                delegate: ItemDelegate {
                    width: ListView.view.width
                    height: Units.gu(6)

                    RowLayout {
                        anchors.fill: parent
                        spacing: Units.gu(1)

                        Image {
                            visible: !!modelData.iconFilePath
                            source: modelData.iconFilePath ? modelData.iconFilePath : ""
                            fillMode: Image.PreserveAspectFit
                            Layout.preferredWidth: Units.gu(3.2)
                            Layout.preferredHeight: Units.gu(3.2)
                        }
                        Label {
                            Layout.fillWidth: true
                            text: modelData.displayName
                            elide: Text.ElideRight
                            font.bold: modelData.id === pageRoot.defaultSearchEngineId
                            font.pixelSize: FontUtils.sizeToPixels("medium")
                        }
                    }

                    HorizontalSeparator {
                        anchors.bottom: parent.bottom
                        width: parent.width
                    }

                    onClicked: {
                        pageRoot.setDefaultSearchEngine(modelData.id);
                        searchEnginePicker.close();
                    }
                }
            }

            Button {
                Layout.fillWidth: true
                text: "Cancel"
                onClicked: searchEnginePicker.close()
            }
        }
    }

    /*
     * Bindings with LuneOS settings
     */
    function retrieveProperties() {
        luna.call("luna://" + searchService + "/getAllSearchPreference", "{}",
                  _handleGetPreferences, _handleServiceUnavailable);

        // Subscribed: installing an application that offers a search or an
        // action changes these lists while the page is open.
        luna.subscribe("luna://" + searchService + "/getUniversalSearchList",
                       JSON.stringify({"subscribe": true}),
                       _handleGetSearchList, _handleServiceUnavailable);
    }

    function _handleGetPreferences(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue || !response.SearchPreference)
            return;

        var prefs = response.SearchPreference;

        // The service writes these as the strings "true"/"false", not as
        // booleans - it always has.
        if (prefs.hasOwnProperty("AppSearch"))
            pageRoot.appSearch = _asBool(prefs.AppSearch);
        if (prefs.hasOwnProperty("ContactSearch"))
            pageRoot.contactSearch = _asBool(prefs.ContactSearch);
        if (prefs.hasOwnProperty("GAL")) {
            pageRoot.galSearch = _asBool(prefs.GAL);
            pageRoot.galSupported = true;
        }
        if (prefs.hasOwnProperty("defaultSearch"))
            pageRoot.defaultSearch = _asBool(prefs.defaultSearch);
        if (prefs.hasOwnProperty("defaultSearchEngine"))
            pageRoot.defaultSearchEngineId = prefs.defaultSearchEngine;

        pageRoot.serviceAvailable = true;
    }

    function _asBool(value) {
        return value === true || value === "true";
    }

    function _handleGetSearchList(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue)
            return;

        if (response.hasOwnProperty("UniversalSearchList"))
            pageRoot.searchItems = response.UniversalSearchList;
        if (response.hasOwnProperty("DBSearchItemList"))
            pageRoot.contentItems = response.DBSearchItemList;
        if (response.hasOwnProperty("ActionList"))
            pageRoot.actionItems = response.ActionList;

        if (response.hasOwnProperty("defaultSearchEngine"))
            pageRoot.defaultSearchEngineId = response.defaultSearchEngine;

        pageRoot.serviceAvailable = true;
    }

    function _handleServiceUnavailable(message) {
        console.warn("Universal search service did not answer: " + message);
        pageRoot.serviceAvailable = false;
    }

    // Push changes to LuneOS
    function setSearchPreference(key, value) {
        if (key === "AppSearch")
            pageRoot.appSearch = value;
        else if (key === "ContactSearch")
            pageRoot.contactSearch = value;
        else if (key === "GAL")
            pageRoot.galSearch = value;
        else if (key === "defaultSearch")
            pageRoot.defaultSearch = value;

        luna.call("luna://" + searchService + "/setSearchPreference",
                  JSON.stringify({"key": key, "value": value}),
                  _handleSetSuccess, _handleSetError);
    }

    function setSearchItemEnabled(category, itemId, enabled) {
        _updateLocalItem(category, itemId, enabled);

        luna.call("luna://" + searchService + "/updateSearchItem",
                  JSON.stringify({"id": itemId, "enabled": enabled,
                                  "category": category, "setDefault": false}),
                  _handleSetSuccess, _handleSetError);
    }

    function setAllSearchItems(category, enabled) {
        var items = _itemsFor(category).slice();
        for (var i = 0; i < items.length; i++)
            items[i] = _withEnabled(items[i], enabled);
        _storeItems(category, items);

        luna.call("luna://" + searchService + "/updateAllSearchItems",
                  JSON.stringify({"category": category, "enabled": enabled}),
                  _handleSetSuccess, _handleSetError);
    }

    function setDefaultSearchEngine(itemId) {
        pageRoot.defaultSearchEngineId = itemId;

        luna.call("luna://" + searchService + "/updateSearchItem",
                  JSON.stringify({"id": itemId, "enabled": true,
                                  "category": "search", "setDefault": true}),
                  _handleSetSuccess, _handleSetError);
    }

    /*
     * The lists are plain arrays handed over by the service, so a change has
     * to be written back as a new array for the Repeaters to notice it. The
     * subscription will confirm it a moment later; this is only so the
     * checkbox does not spring back in the meantime.
     */
    function _itemsFor(category) {
        if (category === "dbsearch")
            return pageRoot.contentItems;
        if (category === "action")
            return pageRoot.actionItems;
        return pageRoot.searchItems;
    }

    function _storeItems(category, items) {
        if (category === "dbsearch")
            pageRoot.contentItems = items;
        else if (category === "action")
            pageRoot.actionItems = items;
        else
            pageRoot.searchItems = items;
    }

    function _withEnabled(item, enabled) {
        var copy = {};
        for (var key in item)
            copy[key] = item[key];
        copy.enabled = enabled;
        return copy;
    }

    function _updateLocalItem(category, itemId, enabled) {
        var items = _itemsFor(category).slice();
        for (var i = 0; i < items.length; i++) {
            if (items[i].id === itemId)
                items[i] = _withEnabled(items[i], enabled);
        }
        _storeItems(category, items);
    }
}
