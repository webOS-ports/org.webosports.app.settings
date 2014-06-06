configure_file(config.h.in ${CMAKE_CURRENT_BINARY_DIR}/config.h @ONLY)

include_directories(
    ${CMAKE_CURRENT_BINARY_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${GLIB2_INCLUDE_DIRS}
    ${WEBOS_APPLICATION_INCLUDE_DIRS})

set(SOURCES
    main.cpp
    settingsapplication.cpp)

add_executable(org.webosports.app.settings ${SOURCES} ${RESOURCES})
qt5_use_modules(org.webosports.app.settings Core Gui Qml Quick)
target_link_libraries(org.webosports.app.settings
    ${GLIB2_LIBRARIES}
    ${WEBOS_APPLICATION_LIBRARIES})

install(TARGETS org.webosports.app.settings DESTINATION ${APP_DIR})

install(DIRECTORY qml DESTINATION ${APP_DIR})

webos_build_system_bus_files()
