import QtQuick
Item {
  property var anchorItem; property var bar; property var owner; property bool open; property var focusTarget
  property real contentWidth: 400; property real contentHeight: 600
  property real screenH: 1440
  width: contentWidth; height: contentHeight
  function cappedContentHeight(h) { return h }
  function fittedContentWidth(w) { return w }
}
