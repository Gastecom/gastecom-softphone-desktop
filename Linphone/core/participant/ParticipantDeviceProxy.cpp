/*
 * Copyright (c) 2024 Belledonne Communications SARL.
 *
 * This file is part of linphone-desktop
 * (see https://www.linphone.org).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "ParticipantDeviceProxy.hpp"
#include "ParticipantDeviceList.hpp"
#include "core/App.hpp"
#include "tool/Utils.hpp"

#include <QQmlApplicationEngine>

// =============================================================================

DEFINE_ABSTRACT_OBJECT(ParticipantDeviceProxy)
DEFINE_GUI_OBJECT(ParticipantDeviceProxy)

ParticipantDeviceProxy::ParticipantDeviceProxy(QObject *parent) : LimitProxy(parent) {
	mParticipants = ParticipantDeviceList::create();
	connect(mParticipants.get(), &ParticipantDeviceList::countChanged, this, &ParticipantDeviceProxy::meChanged,
	        Qt::QueuedConnection);
	connect(mParticipants.get(), &ParticipantDeviceList::currentCallChanged, this,
	        &ParticipantDeviceProxy::currentCallChanged);

	setSourceModels(new SortFilterList(mParticipants.get(), Qt::AscendingOrder));
}

ParticipantDeviceProxy::~ParticipantDeviceProxy() {
}

CallGui *ParticipantDeviceProxy::getCurrentCall() const {
	return mParticipants ? mParticipants->getCurrentCall() : nullptr;
}

void ParticipantDeviceProxy::setCurrentCall(CallGui *call) {
	lDebug() << log().arg("Set current call") << this << " => " << call;
	if (mParticipants) mParticipants->setCurrentCall(call);
}

ParticipantDeviceGui *ParticipantDeviceProxy::getMe() const {
	auto core = mParticipants->getMe();
	if (!core) return nullptr;
	else {
		return new ParticipantDeviceGui(core);
	}
}

bool ParticipantDeviceProxy::SortFilterList::filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const {
	return true;
}

bool ParticipantDeviceProxy::SortFilterList::lessThan(const QModelIndex &sourceLeft,
                                                      const QModelIndex &sourceRight) const {
	auto l = getItemAtSource<ParticipantDeviceList, ParticipantDeviceCore>(sourceLeft.row());
	auto r = getItemAtSource<ParticipantDeviceList, ParticipantDeviceCore>(sourceRight.row());

	return r->isMe() || (!r->isMe() && sourceLeft.row() < sourceRight.row());
}
