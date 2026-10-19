import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Linphone
import UtilsCpp
import 'qrc:/qt/qml/Linphone/view/Control/Tool/Helper/utils.js' as Utils
import "qrc:/qt/qml/Linphone/view/Style/buttonStyle.js" as ButtonStyle


IconLabelButton {
	id: mainItem

	property var accountGui
	property var presence
	signal click()
	
    height: Utils.getSizeWithScreenRatio(22)
    radius: Utils.getSizeWithScreenRatio(5)
	text: UtilsCpp.getPresenceStatus(presence)
	textSize: Typography.p1.pixelSize
	textColor: UtilsCpp.getPresenceColor(presence)
	pressedTextColor: textColor
	hoveredTextColor: textColor
	textWeight: Typography.p1.weight
	icon.width: Utils.getSizeWithScreenRatio(11)
	icon.height: Utils.getSizeWithScreenRatio(11)
	icon.source: UtilsCpp.getPresenceIcon(presence)
	property var imagesource: icon.source
	color: "#00000000"
	hoveredColor: UtilsCpp.getPresenceBackgroundColor(presence)
	pressedColor: UtilsCpp.getPresenceBackgroundColor(presence)
	contentImageColor: undefined
	pressedImageColor: undefined
	hoveredImageColor: undefined
	Layout.fillWidth: true
	shadowEnabled: false
	padding: 0

	onClicked: {
		accountGui.core.presence = presence
		click()
	}
}
