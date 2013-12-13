find_program(NODEJS_BIN node)

add_custom_target(app ALL COMMAND
    ${NODEJS_BIN} ${CMAKE_SOURCE_DIR}/enyo/tools/deploy.js
    -s ${CMAKE_SOURCE_DIR}
    -o ${CMAKE_BINARY_DIR}/deploy/${CMAKE_PROJECT_NAME})

# Install the application itself
install(DIRECTORY ${CMAKE_BINARY_DIR}/deploy/${CMAKE_PROJECT_NAME} DESTINATION palm/applications)

# Install other necessary files not picked up within the enyo build process
install(FILES ${CMAKE_SOURCE_DIR}/appinfo.json DESTINATION palm/applications/${CMAKE_PROJECT_NAME})
