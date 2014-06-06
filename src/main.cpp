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

#include "settingsapplication.h"
#include "config.h"

int main(int argc, char **argv)
{
    SettingsApplication::setApplicationName("Accounts App");
    SettingsApplication application(argc, argv);

    if (!application.setup(QString("%1/main.qml").arg(settingsAppDirectory())))
        return 0;

    return application.exec();
}
