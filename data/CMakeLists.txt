macro(install_symlink filepath sympath)
    install(CODE "execute_process(COMMAND ${CMAKE_COMMAND} -E create_symlink ${filepath} \$ENV{DESTDIR}/${sympath})")
    install(CODE "message(\"-- Created symlink: ${sympath} -> ${filepath}\")")
endmacro(install_symlink)

# For each category, install the appinfo and the LS2 json files
foreach(CATEGORY
  backup
  bluetooth
  certificate
  dateandtime
  deviceinfo
  devmodeswitcher
  exhibitionpreferences
  help
  languagepicker
  location
  networksettings
  screenlock
  searchpreferences
  soundsandalerts
  textassist
  updates
  vpn
  wifi)
  # for a new category, just add the name up there.
  # it will correspond to the app name suffix put after org.webosports.app.settings.

    # install the appinfo.json for this category
    set(APPINFO_JSON_${CATEGORY} appinfo.${CATEGORY}.json)
    install(FILES ${APPINFO_JSON_${CATEGORY}}
            DESTINATION ${WEBOS_INSTALL_WEBOS_APPLICATIONSDIR}/org.webosports.app.settings.${CATEGORY}
            RENAME appinfo.json)

    install_symlink(${APP_DIR}/qml ${WEBOS_INSTALL_WEBOS_APPLICATIONSDIR}/org.webosports.app.settings.${CATEGORY}/qml)
endforeach()

add_custom_target(AppInfoFiles SOURCES ${APPINFO_JSON_ALL})
