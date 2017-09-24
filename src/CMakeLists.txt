install(TARGETS org.webosports.app.settings DESTINATION ${APP_DIR})
install(DIRECTORY qml DESTINATION ${APP_DIR})

webos_build_system_bus_files()
