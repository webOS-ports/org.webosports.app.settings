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

#include <applicationenvironment.h>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDBusAbstractAdaptor>

#include "wifimanager.h"

WiFiManager::WiFiManager(luna::ApplicationEnvironment *environment, QObject *parent) :
    luna::BaseExtension("WiFiManager", environment, parent),
    mManager(0),
    mWifi(0),
    mConnecting(false),
    mDisconnecting(false),
    mNetworkToConnect(0),
    mAgent(this)
{
    mManager = NetworkManagerFactory::createInstance();
    mWifi = mManager->getTechnology("wifi");
    if (mWifi)
        connectWifiSignals();

    connect(mManager, SIGNAL(availabilityChanged(bool)),
            this, SLOT(managerAvailabilityChanged(bool)));
    connect(mManager, SIGNAL(servicesChanged()),
            this, SLOT(servicesChanged()));

    connect(&mAgent, SIGNAL(userInputRequested(const QString&, const QVariantMap&)),
            this, SLOT(handleUserInputRequested(const QString&, const QVariantMap&)));

    environment->registerUserScript(QUrl("qrc:///extensions/WiFiManager/WiFiManager.js"));
}

void WiFiManager::initialize()
{
    bool wifiPowered = mWifi ? mWifi->powered() : false;
    mAppEnvironment->executeScript(QString("__WiFiManager.setPowered(%1);").arg(wifiPowered ? "true" : "false"));
}

void WiFiManager::connectWifiSignals()
{
    connect(mWifi, SIGNAL(scanFinished()), this, SLOT(scanFinished()));
}

void WiFiManager::managerAvailabilityChanged(bool available)
{
}

void WiFiManager::servicesChanged()
{
    QString payload = createNetworksResponse();
    mAppEnvironment->executeScript(QString("__WiFiManager.networksChanged(%1);").arg(payload));
}

void WiFiManager::technologiesChanged()
{
    if (mWifi && mManager->getTechnology("wifi") == NULL)
        mWifi = NULL;
    else if (mWifi == NULL) {
        mWifi = mManager->getTechnology("wifi");
        if (mWifi) {
            connectWifiSignals();
            initialize();
        }
    }
}

QString WiFiManager::createNetworksResponse()
{
    QJsonDocument document;
    QJsonArray networksArray;

    foreach(NetworkService *network, mManager->getServices("wifi")) {
        QJsonObject networkObj;

        networkObj.insert("path", QJsonValue(network->path()));
        networkObj.insert("name", QJsonValue(network->name()));
        networkObj.insert("state", QJsonValue(network->state()));
        networkObj.insert("error", QJsonValue(network->error()));

        QJsonArray securityArray;
        foreach(QString securityType, network->security())
            securityArray.append(QJsonValue(securityType));
        networkObj.insert("security", securityArray);

        networkObj.insert("strength", QJsonValue((int) network->strength()));
        networkObj.insert("favorite", QJsonValue(network->favorite()));
        networkObj.insert("autoconnect", QJsonValue(network->autoConnect()));
        networkObj.insert("connected", QJsonValue(network->connected()));
        networkObj.insert("roaming", QJsonValue(network->roaming()));

        // FIXME add the following missing parts
        // - ipv4/ipv6 configuration
        // - nameservers
        // - domains
        // - proxy configuration

        networksArray.append(QJsonValue(networkObj));
    }

    document.setArray(networksArray);

    return document.toJson();
}

void WiFiManager::scanFinished()
{
    QString payload = createNetworksResponse();
    foreach(CallbackHandle request, mScanRequests) {
        callback(request.first, payload);
    }

    mScanRequests.clear();
}

void WiFiManager::handleUserInputRequested(const QString &servicePath, const QVariantMap &fields)
{
    qDebug() << __PRETTY_FUNCTION__ << servicePath << fields;

    if (!mConnecting)
        return;

    QVariantMap replyFields;

    if (fields.contains("Passphrase")) {
        replyFields.insert("Passphrase", QVariant(mNetworkPassword));
    }

    mAgent.sendUserReply(replyFields);
}

void WiFiManager::setPowered(bool powered)
{
    if (!mWifi)
        return;

    mWifi->setPowered(powered);
}

void WiFiManager::retrieveNetworks(int scid, int ecid)
{
    if (!mWifi) {
        callback(ecid, "WiFi is not available");
        return;
    }

    mScanRequests.append(CallbackHandle(scid, ecid));

    mWifi->scan();
}

void WiFiManager::connectRequestFailed(const QString& error)
{
    qDebug() << __PRETTY_FUNCTION__;

    finishConnectionProcess(false, error);
}

void WiFiManager::networkConnected(bool connected)
{
    qDebug() << __PRETTY_FUNCTION__ << connected;

    bool success = false;

    if ((mConnecting && connected) || (mDisconnecting && !connected))
        success = true;

    finishConnectionProcess(success, "");
}

void WiFiManager::finishConnectionProcess(bool success, const QString &error)
{
    qDebug() << __PRETTY_FUNCTION__;

    if (mConnecting)
        callback(success ? mConnectCallbacks.first : mConnectCallbacks.second, error);
    else if (mDisconnecting)
        callback(success ? mDisconnectCallbacks.first : mDisconnectCallbacks.second, error);

    mConnectCallbacks.first = 0;
    mConnectCallbacks.second = 0;

    if (mNetworkToConnect) {
      delete mNetworkToConnect;
      mNetworkToConnect = 0;
    }

    mConnecting = false;
    mDisconnecting = false;

    disconnect(this, SLOT(networkConnected(bool)));
    disconnect(this, SLOT(connectRequestFailed(const QString&)));
}

void WiFiManager::connectNetwork(int scid, int ecid, const QString &network)
{
    qDebug() << __PRETTY_FUNCTION__ << network;

    if (mConnecting) {
        callback(ecid, "Already connecting to a network");
        return;
    }

    mNetworkToConnect = 0;
    QString path;
    QJsonDocument document = QJsonDocument::fromJson(network.toUtf8());

    if (!document.isObject()) {
        callback(ecid, "Invalid arguments");
        return;
    }

    QJsonObject root = document.object();
    if (!root.contains("path") || !root.value("path").isString()) {
        callback(ecid, "Invalud arguments");
        return;
    }

    path = root.value("path").toString();

    if (!root.contains("password") || !root.value("password").isString()) {
        callback(ecid, "Invalud arguments");
        return;
    }

    mNetworkPassword = root.value("password").toString();

    QVariantMap emptyProperties;
    mNetworkToConnect = new NetworkService(path, emptyProperties, 0);

    mConnecting = true;
    mConnectCallbacks.first = scid;
    mConnectCallbacks.second = ecid;

    connect(mNetworkToConnect, SIGNAL(connectedChanged(bool)),
            this, SLOT(networkConnected(bool)));
    connect(mNetworkToConnect, SIGNAL(connectRequestFailed(const QString&)),
            this, SLOT(connectRequestFailed(const QString&)));

    mNetworkToConnect->requestConnect();
}

void WiFiManager::disconnectNetwork(const QString &path)
{
    qDebug() << __PRETTY_FUNCTION__ << path;

    if (mConnecting)
        return;

    QVariantMap emptyProperties;
    NetworkService networkToDisconnect(path, emptyProperties, 0);

    networkToDisconnect.requestDisconnect();
}

void WiFiManager::setNetworkOption(const QString &path, const QString &key, const QVariant &value)
{
    qDebug() << __PRETTY_FUNCTION__ << path << key << value;

    QVariantMap emptyProperties;
    NetworkService networkToConfigure(path, emptyProperties, 0);
}

void WiFiManager::removeNetwork(const QString &path)
{
    qDebug() << __PRETTY_FUNCTION__ << path;

    QVariantMap emptyProperties;
    NetworkService networkToRemove(path, emptyProperties, 0);

    networkToRemove.remove();
}
