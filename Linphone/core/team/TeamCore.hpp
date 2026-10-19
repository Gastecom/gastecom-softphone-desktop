/*
 * Gastecom - pestaña "Equipo" (BLF, 2026-08-19)
 *
 * Expone a QML la lista de companeros configurada por aprovisionamiento
 * (seccion "gastecom_team" del XML), con su estado de llamada en vivo
 * (SUBSCRIBE Event:dialog, RFC 4235). Los datos llegan desde CoreModel via
 * la senal teamMembersUpdated, en el hilo del Core; aqui solo se guardan
 * para pintarlos, sin tocar nada del SDK directamente.
 */

#ifndef TEAM_CORE_H_
#define TEAM_CORE_H_

#include "tool/AbstractObject.hpp"

#include <QObject>
#include <QVariantList>

class TeamCore : public QObject, public AbstractObject {
	Q_OBJECT
	Q_PROPERTY(QVariantList members READ getMembers NOTIFY membersChanged)
	Q_PROPERTY(bool available READ getAvailable NOTIFY membersChanged)

public:
	TeamCore(QObject *parent = nullptr);
	~TeamCore() = default;

	QVariantList getMembers() const {
		return mMembers;
	}
	// true si el aprovisionamiento trae seccion "gastecom_team": permite a la
	// UI decidir si mostrar la pestana Equipo o no (perfil sin equipo
	// configurado no muestra nada).
	bool getAvailable() const {
		return !mMembers.isEmpty();
	}

public slots:
	void setMembers(const QVariantList &members);

signals:
	void membersChanged();

private:
	QVariantList mMembers;

	DECLARE_ABSTRACT_OBJECT
};

#endif // TEAM_CORE_H_
