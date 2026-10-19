/*
 * Copyright (c) 2021 Belledonne Communications SARL.
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

#ifndef PARTICIPANT_DEVICE_LIST_H_
#define PARTICIPANT_DEVICE_LIST_H_

#include "../proxy/ListProxy.hpp"
#include "ParticipantDeviceCore.hpp"
#include "core/conference/ConferenceCore.hpp"
#include "model/conference/ConferenceModel.hpp"
#include "tool/AbstractObject.hpp"
#include "tool/thread/SafeConnection.hpp"

class ParticipantDeviceList : public ListProxy, public AbstractObject {
	Q_OBJECT

public:
	static QSharedPointer<ParticipantDeviceList> create();

	ParticipantDeviceList();
	~ParticipantDeviceList();

	QList<QSharedPointer<ParticipantDeviceCore>> *
	buildDevices(const std::shared_ptr<ConferenceModel> &conferenceModel) const;

	QSharedPointer<ParticipantDeviceCore> getMe() const;

	void setDevices(QList<QSharedPointer<ParticipantDeviceCore>> devices);
	QSharedPointer<ParticipantDeviceCore> findDeviceByUniqueAddress(const QString &address);
	void setConferenceCore(const QSharedPointer<ConferenceCore> &conference);
	void setCurrentCall(CallGui *call);
	CallGui *getCurrentCall() const;

	void setSelf(QSharedPointer<ParticipantDeviceList> me);

	virtual QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;

signals:
	void currentCallChanged();

private:
	CallGui *mCurrentCall = nullptr;
	QSharedPointer<ConferenceCore> mConferenceCore;
	// std::shared_ptr<ConferenceModel> mConferenceModel;
	QSharedPointer<SafeConnection<ParticipantDeviceList, CoreModel>> mCoreModelConnection;

	DECLARE_ABSTRACT_OBJECT
};
Q_DECLARE_METATYPE(QSharedPointer<ParticipantDeviceList>);

#endif // PARTICIPANT_DEVICE_LIST_H_
