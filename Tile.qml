import QtQuick
import qs.Commons

// One tile in the drawer: a glyph, a short label and a state line. The tile
// owns no state; the drawer passes the label, icon, state, click and reorder
// handlers in.
Item {
  id: root

  property QtObject bar: null
  property string icon: ""
  property string label: ""
  property bool active: false
  // Action tiles (panel shortcuts, custom commands) have no on/off state.
  property bool action: false
  property string statusText: action ? "Run" : (active ? "On" : "Off")

  // Reordering is handled by the drawer; the tile only reports pointer travel.
  property bool reorderable: false
  property bool interactive: true
  property bool dragActive: false
  property bool dropTarget: false

  signal clicked()
  signal dragStarted(var tile, real x, real y)
  signal dragMoved(var tile, real x, real y)
  signal dragFinished(var tile, real x, real y)
  signal dragCancelled()

  implicitWidth: Style.space(96)
  implicitHeight: Style.space(84)

  opacity: dragActive ? 0.25 : 1

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color activeColor: Color.accent
  readonly property color mutedColor: Util.alpha(foreground, 0.55)
  readonly property bool highlighted: (active && !action) || dropTarget

  Behavior on opacity { NumberAnimation { duration: 100 } }

  Rectangle {
    id: surface
    anchors.fill: parent
    radius: Style.cornerRadius
    color: root.dropTarget
      ? Util.alpha(root.activeColor, 0.20)
      : (root.highlighted
        ? Util.alpha(root.activeColor, 0.16)
        : (hover.hovered ? Util.alpha(root.foreground, 0.10) : Util.alpha(root.foreground, 0.05)))
    border.width: root.dropTarget ? 2 : 1
    border.color: root.highlighted ? root.activeColor : Util.alpha(root.foreground, 0.14)

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Column {
      anchors.centerIn: parent
      spacing: Style.space(3)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.icon
        color: root.highlighted ? root.activeColor : root.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.iconLarge
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        width: surface.width - Style.space(8)
        text: root.label
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        color: root.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.statusText
        color: root.highlighted ? root.activeColor : root.mutedColor
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }

    HoverHandler { id: hover }
  }

  MouseArea {
    id: pointer

    anchors.fill: parent
    enabled: root.interactive
    hoverEnabled: true
    preventStealing: root.reorderable
    cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

    property point pressPoint: Qt.point(0, 0)
    property bool dragging: false
    property bool suppressClick: false

    onPressed: function(mouse) {
      pressPoint = Qt.point(mouse.x, mouse.y)
      dragging = false
      suppressClick = false
    }

    onPositionChanged: function(mouse) {
      if (!root.reorderable || !pressed) return
      var dx = mouse.x - pressPoint.x
      var dy = mouse.y - pressPoint.y
      if (!dragging && Math.abs(dx) + Math.abs(dy) >= Style.space(8)) {
        dragging = true
        root.dragStarted(root, mouse.x, mouse.y)
      }
      if (dragging) root.dragMoved(root, mouse.x, mouse.y)
    }

    onReleased: function(mouse) {
      if (dragging) {
        dragging = false
        suppressClick = true
        root.dragFinished(root, mouse.x, mouse.y)
        return
      }
      if (!suppressClick && containsMouse) root.clicked()
    }

    onCanceled: {
      if (dragging) {
        dragging = false
        root.dragCancelled()
      }
      suppressClick = false
    }
  }
}
