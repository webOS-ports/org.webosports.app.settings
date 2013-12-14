include_directories(${WEBAPP_PLUGIN_INCLUDE_DIRS})

set(SOURCES settingsplugin.cpp)

set(CMAKE_SHARED_MODULE_PREFIX "")

add_library(WebosPortsSettingsAppPlugin MODULE ${SOURCES})
qt5_use_modules(WebosPortsSettingsAppPlugin Core)
target_link_libraries(WebosPortsSettingsAppPlugin ${WEBAPP_PLUGIN_LDFLAGS})

install(TARGETS WebosPortsSettingsAppPlugin DESTINATION ${WEBOS_INSTALL_WEBOS_APPLICATIONSDIR}/${PROJECT_NAME}/plugins)
