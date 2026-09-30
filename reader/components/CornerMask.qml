import QtQuick
import QtQuick.Shapes

// Rounds the corners of whatever is beneath it by painting the four
// outside-the-curve slivers in the surrounding colour. Plain vector paths:
// unlike shader clipping it renders everywhere, offscreen grabs included.
Item {
  id: root
  property real radius: 6
  property color color: "black"

  Repeater {
    model: 4
    Shape {
      id: corner
      required property int index
      readonly property bool flipX: index === 1 || index === 2
      readonly property bool flipY: index >= 2
      x: flipX ? root.width - root.radius : 0
      y: flipY ? root.height - root.radius : 0
      width: root.radius
      height: root.radius
      preferredRendererType: Shape.CurveRenderer
      transform: Scale {
        origin.x: root.radius / 2; origin.y: root.radius / 2
        xScale: corner.flipX ? -1 : 1
        yScale: corner.flipY ? -1 : 1
      }
      ShapePath {
        fillColor: root.color
        strokeColor: "transparent"
        startX: 0; startY: 0
        PathLine { x: root.radius; y: 0 }
        PathArc { x: 0; y: root.radius; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Counterclockwise }
        PathLine { x: 0; y: 0 }
      }
    }
  }
}
