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

#ifndef SETTINGSAPPLICATION_H
#define SETTINGSAPPLICATION_H

#include <QObject>
#include <QQmlEngine>
#include <QGuiApplication>

class SettingsApplication : public QGuiApplication
{
    Q_OBJECT
    Q_PROPERTY(QString launchParameters READ launchParameters)

public:
    explicit SettingsApplication(int& argc, char **argv);
    virtual ~SettingsApplication();

    bool setup(const QString& path);

    QString launchParameters() const;

    static void onRelaunch(const char *parameters, void *user_data);

signals:
    void relaunched(const QString& parameters);

private:
    void relaunch(const char *parameters);

private:
    QQmlEngine mEngine;
    QString mLaunchParameters;
};

#endif // SETTINGSAPPLICATION_H
