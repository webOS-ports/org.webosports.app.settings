macro(install_symlink filepath sympath)
    install(CODE "execute_process(COMMAND ${CMAKE_COMMAND} -E create_symlink ${filepath} \$ENV{DESTDIR}/${sympath})")
    install(CODE "message(\"-- Created symlink: ${sympath} -> ${filepath}\")")
endmacro(install_symlink)

# For each category, install the appinfo and the LS2 json files
foreach(CATEGORY
  wifi
  bluetooth)
  # for a new category, just add the name up there.
  # it will correspond to the app name suffix put after org.webosports.app.settings.

    # install the appinfo.json for this category
    set(APPINFO_JSON_${CATEGORY} appinfo.${CATEGORY}.json)
    install(FILES ${APPINFO_JSON_${CATEGORY}}
            DESTINATION ${WEBOS_INSTALL_WEBOS_APPLICATIONSDIR}/org.webosports.app.settings.${CATEGORY}
            RENAME appinfo.json)

    install_symlink(${APP_DIR}/qml ${WEBOS_INSTALL_WEBOS_APPLICATIONSDIR}/org.webosports.app.settings.${CATEGORY}/qml)

    # generate a dedicated LS2 json file for this category
    set(APPINFO_JSON_ALL ${APPINFO_JSON_ALL} ${APPINFO_JSON_${CATEGORY}})
    configure_file(../files/sysbus/org.webosports.app.settings.json.prv.in.in ${CMAKE_CURRENT_BINARY_DIR}/tmp/files/sysbus/org.webosports.app.settings.${CATEGORY}.json.prv.in)
endforeach()

add_custom_target(AppInfoFiles SOURCES ${APPINFO_JSON_ALL})

# install all the generated ls2 files
webos_build_system_bus_files(${CMAKE_CURRENT_BINARY_DIR}/tmp/files/sysbus)
