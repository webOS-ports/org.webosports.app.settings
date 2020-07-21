/*
 * (c) 2017 Christophe Chapuis <chris.chapuis@gmail.com>
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

import MeeGo.QOfono 0.2


/*
 * This is an example of what the code for some settings can look like
 * It is supposed to be a set of good practices, don't hesitate to
 * copy/paste code from here and adapt to your needs.
 *
 * Note: All the settings here are fake. Of Course.
 */
BasePage {
    id: pageRoot

    OfonoManager {
        id: ofonoManager
        onAvailableChanged: {
           console.log("Herrie ofono is " + available ? "available": "not available")
           //textLine2.text = modemManager.available ? netreg.currentOperator["Name"].toString() :"Ofono not available"
        }
        onModemAdded: {
            console.log("Herrie modem added "+modem)
        }
        onModemRemoved: {
            console.log("Herrie modem removed "+modem)
        }
        onModemsChanged: {
            console.log("Herrie modems changed "+modems)
        }
        onDefaultModemChanged: {
            console.log("Herrie default modem changed "+modem)
        }
    }

    /* A settings page has a vertical layout: put everything in a Column */
    Flickable {
        id: flickableItem
        anchors.fill: parent
        anchors.margins: Units.gu(1)
        contentWidth: width
        contentHeight: contentItem.childrenRect.height
        flickableDirection: Flickable.AutoFlickIfNeeded
        clip: true
        Column {
            spacing: Units.gu(2)
            width: parent.width

            Repeater {
                width: parent.width
                model: ofonoManager.modems.length
                delegate: /* GroupBoxes look good! */
                          GroupBox {
                    //property int modemId: model.index
                    width: parent.width

                    title: "Information SIM " + (index + 1)
                    Column {
                        width: parent.width
                        LabelAndValue {
                            visible: netreg.name
                            width: parent.width
                            label: "Operator: "
                            value: netreg.name
                        }
                        HorizontalSeparator {
                            width: parent.width
                        }
                        LabelAndValue {
                            visible: netreg.mode != ""
                            width: parent.width
                            label: "Mode: "
                            value: netreg.mode
                        }
                        HorizontalSeparator {
                            width: parent.width
                        }
                        LabelAndValue {
                            visible: netreg.cellId != ""
                            width: parent.width
                            label: "Cell Id: "
                            value: netreg.cellId
                        }
                        HorizontalSeparator {
                            width: parent.width
                        }
                        LabelAndValue {
                            visible: netreg.mcc != ""
                            width: parent.width
                            label: "MCC: "
                            value: netreg.mcc
                        }
                        HorizontalSeparator {
                            width: parent.width
                        }
                        LabelAndValue {
                            visible: netreg.mnc != ""
                            width: parent.width
                            label: "MNC: "
                            value: netreg.mnc
                        }
                        HorizontalSeparator {
                            width: parent.width
                        }
                        LabelAndValue {
                            visible: netreg.technology != ""
                            width: parent.width
                            label: "Technology: "
                            value: netreg.technology
                        }
                        HorizontalSeparator {
                            width: parent.width
                        }
                        LabelAndValue {
                            visible: netreg.strength  != ""
                            width: parent.width
                            label: "Strength: "
                            value: netreg.strength
                        }
                        HorizontalSeparator {
                            width: parent.width
                        }
                        LabelAndValue {
                            visible: netreg.baseStation   != ""
                            width: parent.width
                            label: "Basestation : "
                            value: netreg.baseStation
                        }
                    }

                    OfonoNetworkRegistration {
                        id: netreg
                        modemPath: ofonoManager.modems[0]
                    }

                }
            }
        }
    }
}
