import QtQuick
import qs.Commons

// One tile in the drawer: a glyph, a short label and a state line. The tile
// owns no state; the drawer passes the label, icon, state and click handler in.
Item {
  id: root

  property QtObject bar: null
  property string icon: ""
  property string label: ""
  property bool active: false
  // Action tiles (panel shortcuts, custom commands) have no on/off state.
  property bool action: false
  property string statusText: action ? "Run" : (active ? "On" : "Off")
  signal clicked()

  implicitWidth: Style.space(96)
  implicitHeight: Style.space(84)

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color activeColor: Color.accent
  readonly property color mutedColor: Util.alpha(foreground, 0.55)
  readonly property bool highlighted: active && !action

  Rectangle {
    id: surface
    anchors.fill: parent
    radius: Style.cornerRadius
    color: root.highlighted
      ? Util.alpha(root.activeColor, 0.16)
      : (hover.hovered ? Util.alpha(root.foreground, 0.10) : Util.alpha(root.foreground, 0.05))
    border.width: 1
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
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
