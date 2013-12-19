/*
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
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
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 */

#ifndef WIFIMANAGER_H
#define WIFIMANAGER_H

#include <QObject>
#include <QList>
#include <networkmanager.h>
#include <networktechnology.h>
#include <networkservice.h>
#include <useragent.h>
#include <baseextension.h>

typedef QPair<int,int> CallbackHandle;

class WiFiManager : public luna::BaseExtension
{
    Q_OBJECT
public:
    explicit WiFiManager(luna::ApplicationEnvironment *environment, QObject *parent = 0);

    void initialize();

public slots:
    void setPowered(bool powered);
    void retrieveNetworks(int scid, int ecid);
    void connectNetwork(int scid, int ecid, const QString &network);
    void disconnectNetwork(const QString &path);
    void setNetworkOption(const QString &path, const QString &key, const QVariant &value);
    void removeNetwork(const QString &path);

private slots:
    void managerAvailabilityChanged(bool available);
    void technologiesChanged();
    void servicesChanged();
    void scanFinished();
    void handleUserInputRequested(const QString &servicePath, const QVariantMap &fields);
    void networkConnected(bool connected);
    void connectRequestFailed(const QString &error);

private:
    NetworkManager *mManager;
    NetworkTechnology *mWifi;
    QList<CallbackHandle> mScanRequests;
    CallbackHandle mConnectCallbacks;
    CallbackHandle mDisconnectCallbacks;
    bool mConnecting;
    bool mDisconnecting;
    NetworkService *mNetworkToConnect;
    UserAgent mAgent;
    QString mNetworkPassword;

    void connectWifiSignals();
    void finishConnectionProcess(bool success, const QString &error);
    QString createNetworksResponse();
};

#endif // WIFIMANAGER_H
