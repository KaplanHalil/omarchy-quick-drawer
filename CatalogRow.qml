import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// One row in the "Add tiles" catalog. The whole row toggles the tile; the
// switch is the visible affordance, and the row click is the easy target.
Item {
  id: root

  property QtObject bar: null
  property string icon: ""
  property string title: ""
  property string description: ""
  property bool checked: false
  property bool available: true
  signal toggled()

  visible: available
  implicitHeight: available ? Style.space(52) : 0

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color mutedColor: Util.alpha(foreground, 0.55)

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: rowMouse.containsMouse ? Util.alpha(root.foreground, 0.06) : "transparent"
  }

  MouseArea {
    id: rowMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled()
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Style.space(6)
    anchors.rightMargin: Style.space(6)
    spacing: Style.space(10)

    Text {
      Layout.preferredWidth: Style.space(24)
      Layout.alignment: Qt.AlignVCenter
      text: root.icon
      horizontalAlignment: Text.AlignHCenter
      color: root.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.iconLarge
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      spacing: 0

      Text {
        Layout.fillWidth: true
        text: root.title
        color: root.foreground
        elide: Text.ElideRight
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
      }

      Text {
        Layout.fillWidth: true
        text: root.description
        color: root.mutedColor
        elide: Text.ElideRight
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
      }
    }

    ToggleSwitch {
      Layout.alignment: Qt.AlignVCenter
      checked: root.checked
      foreground: root.foreground
      accent: Color.accent
      onToggled: root.toggled()
    }
  }
}
