project(org.webosports.app.settings CXX)

cmake_minimum_required(VERSION 2.8)

set(CMAKE_AUTOMOC ON)

include(webOS/webOS)
webos_modules_init(1 0 0 QUALIFIER RC7)
webos_component(0 3 0)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules)

include(WebApp)

find_package(Qt5Core REQUIRED)
if(NOT Qt5Core_FOUND)
    message(FATAL_ERROR "Qt5Core module is required!")
endif()

find_package(Qt5DBus REQUIRED)
if(NOT Qt5DBus_FOUND)
    message(FATAL_ERROR "Qt5DBus module is required!")
endif()

find_package(PkgConfig "0.22" REQUIRED)

pkg_check_modules(WEBAPP_PLUGIN webapp-plugin REQUIRED)
pkg_check_modules(CONNMAN_QT5 connman-qt5 REQUIRED)

add_subdirectory(plugin)
