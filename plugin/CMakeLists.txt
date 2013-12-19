include_directories(
	${WEBAPP_PLUGIN_INCLUDE_DIRS}
	${CONNMAN_QT5_INCLUDE_DIRS})

set(SOURCES
	settingsplugin.cpp
	wifimanager.cpp)

set(CMAKE_SHARED_MODULE_PREFIX "")

qt5_add_resources(RESOURCES extension-wifimanager-resources.qrc)

add_library(WebosPortsSettingsAppPlugin MODULE ${SOURCES} ${RESOURCES})
qt5_use_modules(WebosPortsSettingsAppPlugin Core DBus)
target_link_libraries(WebosPortsSettingsAppPlugin
	${WEBAPP_PLUGIN_LDFLAGS}
	${CONNMAN_QT5_LDFLAGS})

install(TARGETS WebosPortsSettingsAppPlugin DESTINATION ${WEBOS_INSTALL_WEBOS_APPLICATIONSDIR}/${PROJECT_NAME}/plugins)
