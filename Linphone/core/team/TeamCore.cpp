/*
 * Gastecom - pestaña "Equipo" (BLF, 2026-08-19). Ver TeamCore.hpp.
 */

#include "TeamCore.hpp"

DEFINE_ABSTRACT_OBJECT(TeamCore)

TeamCore::TeamCore(QObject *parent) : QObject(parent) {
}

void TeamCore::setMembers(const QVariantList &members) {
	mustBeInMainThread(log().arg(Q_FUNC_INFO));
	mMembers = members;
	emit membersChanged();
}
