import QtQuick 2.4
import Meego.QOfono 0.2

Item {
    readonly property alias simMng: simMng
    readonly property alias present: simMng.present

    property string path
    property string name

    readonly property string title: {
        var number = simMng.subscriberNumbers[0] || simMng.subscriberIdentity;
        return name + (number ? " (" + number + ")" : "");
    }

    OfonoSimManager {
        id: simMng
        modemPath: path
    }
}
