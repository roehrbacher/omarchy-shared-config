import Quickshell
import QtQuick
// Compile check of BarWidget.qml + GlanceVariant.qml (no bar, no scanner run).
ShellRoot {
  Component.onCompleted: {
    var c = Qt.createComponent("BarWidget.qml")
    console.log("LOAD " + (c.status === Component.Ready ? "ok" : "ERR " + c.errorString()))
    Qt.quit()
  }
}
