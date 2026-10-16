import QtQuick
import QtQuick.Shapes
import qs.Commons

// The Insomnia eye (krishhgg/Insomnia, docs/assets/eye-open.svg, MIT, see
// assets/) drawn natively from the SVG's 24-unit mark paths, without its
// tile, so it takes the bar's theme colour like the stock glyph icons.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property real strokeWidth: 2.0

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  Item {
    // Mark spans x 1.5..22.5 and y 1.4..17.6 on the 24 grid: centre it.
    width: 24
    height: 24
    anchors.centerIn: parent
    scale: root.iconSize / 22.5

    Shape {
      x: 0
      y: 2.5
      width: 24
      height: 24
      antialiasing: true
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        fillColor: "transparent"
        strokeColor: root.color
        strokeWidth: root.strokeWidth
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        PathSvg { path: "M1.5 12 C7 4.5 17 4.5 22.5 12 C17 19.5 7 19.5 1.5 12 Z" }
      }
      ShapePath {
        fillColor: root.color
        strokeWidth: 0
        strokeColor: "transparent"
        PathSvg { path: "M15.3953 9.8853 C16.5632 11.7605 15.9899 14.2274 14.1147 15.3953 C12.2395 16.5632 9.7726 15.9899 8.6047 14.1147 C7.4368 12.2395 8.0101 9.7726 9.8853 8.6047 C11.1798 7.7984 12.8202 7.7984 14.1147 8.6047 C13.3441 8.5414 12.6681 9.1147 12.6047 9.8853 C12.5414 10.6559 13.1147 11.3319 13.8853 11.3953 C14.6559 11.4586 15.3319 10.8853 15.3953 10.1147 C15.4016 10.0384 15.4016 9.9616 15.3953 9.8853 Z" }
      }
      ShapePath {
        fillColor: "transparent"
        strokeColor: root.color
        strokeWidth: root.strokeWidth
        capStyle: ShapePath.RoundCap
        PathSvg { path: "M4.5499 6.1977 L3.1442 3.8341 M8.2636 4.6218 L7.5468 1.9668 M12 4.125 L12 1.375 M15.7364 4.6218 L16.4532 1.9668 M19.4501 6.1977 L20.8558 3.8341" }
      }
    }
  }
}
