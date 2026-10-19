/*
 * Gastecom - pestaña "Equipo" (BLF, 2026-08-19)
 *
 * Lista simple de companeros configurados por aprovisionamiento
 * (TeamCpp.members), con su estado de llamada en vivo. Sin panel de
 * detalle todavia -primera version-: solo la lista con el estado.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Control

import Linphone
import TeamCpp
import UtilsCpp
import CustomControls 1.0
import "qrc:/qt/qml/Linphone/view/Style/buttonStyle.js" as ButtonStyle
import "qrc:/qt/qml/Linphone/view/Control/Tool/Helper/utils.js" as Utils

FocusScope {
	id: mainItem

	function stateColor(state) {
		if (state === "terminated") return DefaultStyle.success_500_main;
		if (state === "confirmed" || state === "early" || state === "proceeding" || state === "trying")
			return DefaultStyle.danger_500_main;
		return DefaultStyle.grey_400;
	}
	// TODO: pasar a qsTr() con claves de traduccion cuando el "Equipo" salga
	// de la fase de pruebas; de momento en castellano fijo, como el resto de
	// texto ad-hoc de esta pestana.
	function stateLabel(state) {
		if (state === "terminated") return "Libre";
		if (state === "confirmed" || state === "early" || state === "proceeding" || state === "trying")
			return "En llamada";
		return "Desconocido";
	}

	ColumnLayout {
		anchors.fill: parent
		anchors.margins: Utils.getSizeWithScreenRatio(24)
		spacing: Utils.getSizeWithScreenRatio(16)

		Text {
			text: "Equipo"
			font {
				pixelSize: Typography.h2.pixelSize
				weight: Typography.h2.weight
			}
		}

		Control.ScrollView {
			Layout.fillWidth: true
			Layout.fillHeight: true
			contentWidth: availableWidth

			ColumnLayout {
				width: parent.width
				spacing: Utils.getSizeWithScreenRatio(1)

				Repeater {
					model: TeamCpp.members
					delegate: Rectangle {
						Layout.fillWidth: true
						Layout.preferredHeight: Utils.getSizeWithScreenRatio(64)
						radius: Utils.getSizeWithScreenRatio(10)
						color: DefaultStyle.grey_0

						RowLayout {
							anchors.fill: parent
							anchors.leftMargin: Utils.getSizeWithScreenRatio(16)
							anchors.rightMargin: Utils.getSizeWithScreenRatio(16)
							spacing: Utils.getSizeWithScreenRatio(12)

							// Avatar con inicial + punto de estado como insignia sobre la
							// esquina, igual que en 3CX -antes iba suelto a la izquierda y
							// "Libre" pegado a la derecha, muy lejos del nombre-.
							Item {
								Layout.preferredWidth: Utils.getSizeWithScreenRatio(40)
								Layout.preferredHeight: Utils.getSizeWithScreenRatio(40)

								Rectangle {
									id: avatarCircle
									anchors.fill: parent
									radius: width / 2
									color: DefaultStyle.main2_200
									Text {
										anchors.centerIn: parent
										text: (modelData.name && modelData.name.length > 0 ? modelData.name : modelData.ext).charAt(0).toUpperCase()
										color: DefaultStyle.main2_600
										font {
											pixelSize: Typography.p1.pixelSize
											weight: Typography.h4.weight
										}
									}
								}
								Rectangle {
									width: Utils.getSizeWithScreenRatio(13)
									height: width
									radius: width / 2
									color: mainItem.stateColor(modelData.state)
									border.color: DefaultStyle.grey_0
									border.width: Utils.getSizeWithScreenRatio(2)
									anchors.right: avatarCircle.right
									anchors.bottom: avatarCircle.bottom
								}
							}

							// Sin Layout.fillWidth: si se estira para ocupar toda la fila
							// -que es ancha, la fila de la tarjeta sí es fillWidth-, el
							// texto queda centrado lejos del avatar en vez de pegado.
							// El hueco sobrante lo absorbe el Item spacer de mas abajo.
							ColumnLayout {
								spacing: Utils.getSizeWithScreenRatio(2)
								RowLayout {
									spacing: Utils.getSizeWithScreenRatio(6)
									Text {
										text: modelData.name && modelData.name.length > 0 ? modelData.name : modelData.ext
										font {
											pixelSize: Typography.p1.pixelSize
											weight: Typography.p1.weight
										}
									}
									Text {
										text: modelData.ext
										color: DefaultStyle.main2_400
										font.pixelSize: Utils.getSizeWithScreenRatio(12)
									}
								}
								Text {
									text: mainItem.stateLabel(modelData.state)
									color: mainItem.stateColor(modelData.state)
									font {
										pixelSize: Utils.getSizeWithScreenRatio(12)
										weight: Typography.p2.weight
									}
								}
							}

							// Llamar / enviar mensaje, igual que el icono de telefono que
							// muestra 3CX junto a cada companero del equipo. Pegados al
							// nombre -no al borde derecho de la tarjeta-: el hueco libre
							// va DESPUES de los botones, no antes.
							RowLayout {
								Layout.leftMargin: Utils.getSizeWithScreenRatio(4)
								spacing: Utils.getSizeWithScreenRatio(2)

								IconButton {
									Layout.preferredWidth: Utils.getSizeWithScreenRatio(38)
									Layout.preferredHeight: Utils.getSizeWithScreenRatio(38)
									icon.width: Utils.getSizeWithScreenRatio(20)
									icon.height: Utils.getSizeWithScreenRatio(20)
									icon.source: AppIcons.phone
									radius: Utils.getSizeWithScreenRatio(40)
									style: ButtonStyle.grey
									onClicked: UtilsCpp.createCall(modelData.address)
									//: "Llamar a %1"
									Accessible.name: "Llamar a " + (modelData.name && modelData.name.length > 0 ? modelData.name : modelData.ext)
								}
								IconButton {
									Layout.preferredWidth: Utils.getSizeWithScreenRatio(38)
									Layout.preferredHeight: Utils.getSizeWithScreenRatio(38)
									icon.width: Utils.getSizeWithScreenRatio(20)
									icon.height: Utils.getSizeWithScreenRatio(20)
									icon.source: AppIcons.chatTeardropText
									radius: Utils.getSizeWithScreenRatio(40)
									style: ButtonStyle.grey
									onClicked: mainWindow.displayChatPage(modelData.address)
									//: "Enviar mensaje a %1"
									Accessible.name: "Enviar mensaje a " + (modelData.name && modelData.name.length > 0 ? modelData.name : modelData.ext)
								}
							}
							Item { Layout.fillWidth: true } // absorbe el resto de la fila
						}
					}
				}
			}
		}
	}
}
