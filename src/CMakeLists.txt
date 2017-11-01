install(DIRECTORY qml DESTINATION ${APP_DIR})
FILE(GLOB_RECURSE Files "qml/*.qml" "qml/*.js" "*.png")
add_custom_target(files SOURCES ${Files})
