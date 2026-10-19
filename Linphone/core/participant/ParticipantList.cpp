/*
 * Copyright (c) 2010-2024 Belledonne Communications SARL.
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

#include "ParticipantList.hpp"
#include "core/App.hpp"
#include "core/participant/ParticipantGui.hpp"
#include "model/core/CoreModel.hpp"
#include "model/tool/ToolModel.hpp"
#include "tool/Utils.hpp"

#include <QDebug>

DEFINE_ABSTRACT_OBJECT(ParticipantList)

QSharedPointer<ParticipantList> ParticipantList::create() {
	auto model = QSharedPointer<ParticipantList>(new ParticipantList(), &QObject::deleteLater);
	model->moveToThread(App::getInstance()->thread());
	model->setSelf(model);
	return model;
}

ParticipantList::ParticipantList(QObject *parent) : ListProxy(parent) {
	App::getInstance()->mEngine->setObjectOwnership(this, QQmlEngine::CppOwnership);
}

ParticipantList::~ParticipantList() {
	mList.clear();
}

void ParticipantList::setSelf(QSharedPointer<ParticipantList> me) {
	if (mCoreModelConnection) mCoreModelConnection->disconnect();
	mCoreModelConnection = SafeConnection<ParticipantList, CoreModel>::create(me, CoreModel::getInstance());
	mCoreModelConnection->makeConnectToCore(&ParticipantList::lUpdateParticipants, [this] {
		auto conferenceModel = mConferenceCore ? mConferenceCore->getModel() : nullptr;
		if (!conferenceModel) return;
		mCoreModelConnection->invokeToModel([this, conferenceModel]() {
			QList<QSharedPointer<ParticipantCore>> *participantList = new QList<QSharedPointer<ParticipantCore>>();
			mustBeInLinphoneThread(getClassName());
			std::list<std::shared_ptr<linphone::Participant>> participants;
			participants = conferenceModel->getMonitor()->getParticipantList();
			for (auto it : participants) {
				auto model = ParticipantCore::create(it);
				participantList->push_back(model);
			}
			auto me = conferenceModel->getMonitor()->getMe();
			auto meModel = ParticipantCore::create(me);
			participantList->push_back(meModel);
			mCoreModelConnection->invokeToCore([this, participantList]() {
				mustBeInMainThread(getClassName());
				resetData<ParticipantCore>(*participantList);
				delete participantList;
			});
		});
	});

	mCoreModelConnection->makeConnectToCore(
	    &ParticipantList::lSetParticipantAdminStatus, [this](ParticipantCore *participant, bool status) {
		    auto address = participant->getSipAddress();
		    auto conferenceModel = mConferenceCore ? mConferenceCore->getModel() : nullptr;
		    if (!conferenceModel) return;
		    mCoreModelConnection->invokeToModel([this, conferenceModel, address, status] {
			    auto participants = conferenceModel->getMonitor()->getParticipantList();
			    for (auto &participant : participants) {
				    if (Utils::coreStringToAppString(participant->getAddress()->asStringUriOnly()) == address) {
					    conferenceModel->setParticipantAdminStatus(participant, status);
					    return;
				    }
			    }
		    });
	    });
	emit lUpdateParticipants();
}

void ParticipantList::setConferenceCore(const QSharedPointer<ConferenceCore> &conferenceCore) {
	mustBeInMainThread(log().arg(Q_FUNC_INFO));
	if (mConferenceCore) {
		disconnect(mConferenceCore.get(), &ConferenceCore::participantAdminStatusChanged, this, nullptr);
		disconnect(mConferenceCore.get(), &ConferenceCore::participantAdded, this, nullptr);
		disconnect(mConferenceCore.get(), &ConferenceCore::participantRemoved, this, nullptr);
	}
	mConferenceCore = conferenceCore;
	lDebug() << "[ParticipantList] : set Conference " << conferenceCore.get();
	beginResetModel();
	mList.clear();
	endResetModel();
	if (mConferenceCore) {
		connect(mConferenceCore.get(), &ConferenceCore::participantAdminStatusChanged, this,
		        &ParticipantList::lUpdateParticipants);
		connect(mConferenceCore.get(), &ConferenceCore::participantAdded, this, &ParticipantList::lUpdateParticipants);
		connect(mConferenceCore.get(), &ConferenceCore::participantRemoved, this,
		        &ParticipantList::lUpdateParticipants);
		emit lUpdateParticipants();
	}
}

void ParticipantList::setCurrentCall(CallGui *call) {
	if (mCurrentCall != call) {
		CallCore *callCore = nullptr;
		if (mCurrentCall) {
			callCore = mCurrentCall->getCore();
			if (callCore) disconnect(callCore, &CallCore::conferenceChanged, this, nullptr);
			callCore = nullptr;
		}
		mCurrentCall = call;
		if (mCurrentCall) callCore = mCurrentCall->getCore();
		if (callCore) {
			connect(callCore, &CallCore::conferenceChanged, this, [this]() {
				auto conference = mCurrentCall->getCore()->getConferenceCore();
				lDebug() << "[ParticipantDeviceProxy] set conference " << this << " => " << conference;
				setConferenceCore(conference);
			});
			auto conference = callCore->getConferenceCore();
			lDebug() << "[ParticipantDeviceProxy] set conference " << this << " => " << conference;
			setConferenceCore(conference);
		}
		emit currentCallChanged();
	}
}

CallGui *ParticipantList::getCurrentCall() const {
	return mCurrentCall;
}

QVariant ParticipantList::data(const QModelIndex &index, int role) const {
	int row = index.row();
	if (!index.isValid() || row < 0 || row >= mList.count()) return QVariant();
	if (role == Qt::DisplayRole) {
		return QVariant::fromValue(new ParticipantGui(mList[row].objectCast<ParticipantCore>()));
	}
	return QVariant();
}

std::list<std::shared_ptr<linphone::Address>> ParticipantList::getParticipants() const {
	std::list<std::shared_ptr<linphone::Address>> participants;
	for (auto participant : mList) {
		participants.push_back(ToolModel::interpretUrl(participant.objectCast<ParticipantCore>()->getSipAddress()));
	}
	return participants;
}

bool ParticipantList::contains(const QString &address) const {
	bool exists = false;
	App::postModelBlock([this, address, &exists, participants = mList]() {
		auto testAddress = ToolModel::interpretUrl(address);
		for (auto itParticipant = participants.begin(); !exists && itParticipant != participants.end(); ++itParticipant)
			exists = testAddress->weakEqual(
			    ToolModel::interpretUrl(itParticipant->objectCast<ParticipantCore>()->getSipAddress()));
	});

	return exists;
}

void ParticipantList::remove(ParticipantCore *participant) {
	QString address = participant->getSipAddress();
	int index = 0;
	bool found = false;
	auto itParticipant = mList.begin();
	while (!found && itParticipant != mList.end()) {
		if (itParticipant->objectCast<ParticipantCore>()->getSipAddress() == address) found = true;
		else {
			++itParticipant;
			++index;
		}
	}
	if (found) {
		auto conferenceModel = mConferenceCore ? mConferenceCore->getModel() : nullptr;
		if (!conferenceModel) return;
		mCoreModelConnection->invokeToModel(
		    [this, conferenceModel, address] { conferenceModel->removeParticipant(ToolModel::interpretUrl(address)); });
	}
}

void ParticipantList::addAddress(const QString &address) {

	if (!contains(address)) {
		QSharedPointer<ParticipantCore> participant = QSharedPointer<ParticipantCore>::create(nullptr);
		connect(participant.get(), &ParticipantCore::invitationTimeout, this, &ParticipantList::remove);
		participant->setSipAddress(address);
		add(participant);
		auto conferenceModel = mConferenceCore ? mConferenceCore->getModel() : nullptr;
		if (!conferenceModel) return;
		mCoreModelConnection->invokeToModel([this, conferenceModel, address] {
			std::list<std::shared_ptr<linphone::Call>> runningCallsToAdd;
			auto addressToInvite = ToolModel::interpretUrl(address);
			auto currentCalls = CoreModel::getInstance()->getCore()->getCalls();
			auto haveCall = std::find_if(currentCalls.begin(), currentCalls.end(),
			                             [addressToInvite](const std::shared_ptr<linphone::Call> &call) {
				                             return call->getRemoteAddress()->weakEqual(addressToInvite);
			                             });
			if (haveCall == currentCalls.end()) conferenceModel->addParticipant(addressToInvite);
		});
		emit participant->lStartInvitation();
		emit countChanged();
	}
}
