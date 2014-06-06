/*
 * Copyright (C) 2014 Simon Busch <morphis@gravedo.de>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <QDebug>
#include <QStringList>
#include <QQmlEngine>
#include <QQmlContext>
#include <QQuickItem>

#include <glib.h>
#include <webos_application.h>

#include "settingsapplication.h"

struct webos_application_event_handlers event_handlers = {
    .activate = NULL,
    .deactivate = NULL,
    .suspend = NULL,
    .relaunch = SettingsApplication::onRelaunch,
    .lowmemory = NULL
};

SettingsApplication::SettingsApplication(int& argc, char **argv) :
    QGuiApplication(argc, argv),
    mLaunchParameters("{}")
{
    webos_application_init("org.webosports.app.settings", &event_handlers, this);
    webos_application_attach(g_main_loop_new(g_main_context_default(), TRUE));

    setApplicationName("Settings App");

    if (arguments().size() == 2) {
        mLaunchParameters = arguments().at(1);
        qDebug() << "Launched with parameters: " << mLaunchParameters;
    }
}

SettingsApplication::~SettingsApplication()
{
}

QString SettingsApplication::launchParameters() const
{
    return mLaunchParameters;
}

bool SettingsApplication::setup(const QString& path)
{
    if (path.isEmpty()) {
        qWarning() << "Invalid app path:" << path;
        return false;
    }

    mEngine.rootContext()->setContextProperty("application", this);

    QQmlComponent appComponent(&mEngine, QUrl(path));
    if (appComponent.isError()) {
        qWarning() << "Errors while loading app from" << path;
        qWarning() << appComponent.errors();
        return false;
    }

    QObject *app = appComponent.beginCreate(mEngine.rootContext());
    if (!app) {
        qWarning() << "Error creating app from" << path;
        qWarning() << appComponent.errors();
        return false;
    }

    appComponent.completeCreate();

    return true;
}

void SettingsApplication::onRelaunch(const char *parameters, void *user_data)
{
    SettingsApplication *app = static_cast<SettingsApplication*>(user_data);
    app->relaunch(parameters);
}

void SettingsApplication::relaunch(const char *parameters)
{
    emit relaunched(QString(parameters));
}
