set(ARTIFACT_CATEGORIES "")
set(DERIVED_ARTIFACTS "")

macro(add_prefix PREFIX PATHS OUTPUT_VARIABLE)
  string(STRIP "${PATHS}" PATHS)
  set("${OUTPUT_VARIABLE}" "")
  foreach(PATH "${PATHS}")
    set("${OUTPUT_VARIABLE}" "${${OUTPUT_VARIABLE}} ${PREFIX}${PATH}")
  endforeach()
  string(STRIP "${${OUTPUT_VARIABLE}}" "${OUTPUT_VARIABLE}")
endmacro()

macro(category_to_path CATEGORY OUTPUT_VARIABLE)
  string(REPLACE "_" "/" "${OUTPUT_VARIABLE}" "${CATEGORY}")
endmacro()

macro(get_tool TOOL CONFIGURATION RESULT)
  if(CONFIGURATION IN_LIST NATIVE_CONFIGURATIONS)
    set("${RESULT}" "${TOOL}")
  else()
    set("${RESULT}" "${TRIPLE_${CONFIGURATION}}-${TOOL}")
  endif()
endmacro()

macro(register_artifact_category NAME EXECUTABLE)
  list(APPEND ARTIFACT_CATEGORIES "${NAME}")
  set(ARTIFACT_CATEGORY_${NAME}_EXECUTABLE "${EXECUTABLE}")
endmacro()

macro(register_artifact CATEGORY NAME CONFIGURATION SOURCES)
  # Sources are in CATEGORY/file.c or CATEGORY/CONFIGURATION/file.S
  category_to_path("${CATEGORY}" SOURCES_PATH)

  if(NOT "${CONFIGURATION}" STREQUAL "")
    set(SOURCES_PATH "${SOURCES_PATH}/${CONFIGURATION}")
  endif()

  if(NOT "${NAME}" IN_LIST "ARTIFACTS_${CATEGORY}")
    list(APPEND "ARTIFACTS_${CATEGORY}" "${NAME}")
  endif()
  list(APPEND "ARTIFACT_CONFIGURATION_${CATEGORY}__${NAME}" "${CONFIGURATION}")
  add_prefix("${SOURCES_PATH}/" "${SOURCES}" "ARTIFACT_SOURCES_${CATEGORY}__${NAME}__${CONFIGURATION}")

  if(IN_REVNG_QA)
    foreach(SOURCE ${SOURCES})
      install(FILES ${CMAKE_SOURCE_DIR}/${SOURCES_PATH}/${SOURCE}
        DESTINATION "share/revng/qa/${SOURCES_PATH}/sources/")
    endforeach()
  endif()

  if("${CONFIGURATION}" STREQUAL "")
    foreach(CONFIG IN LISTS CONFIGURATIONS)
      install(CODE "make_directory($ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/share/revng/qa/${SOURCES_PATH}/${CONFIG})")
      install(CODE "execute_process(COMMAND ${CMAKE_COMMAND} -E create_symlink ../sources $ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/share/revng/qa/${SOURCES_PATH}/${CONFIG}/sources)")
    endforeach()
  endif()

endmacro()

macro(register_artifact_run CATEGORY ARTIFACT_NAME NAME ARGUMENTS)
  list(APPEND "ARTIFACT_RUNS_${CATEGORY}__${ARTIFACT_NAME}" "${NAME}")
  set("ARTIFACT_RUNS_${CATEGORY}__${ARTIFACT_NAME}__${NAME}" "${ARGUMENTS}")
endmacro()

set(CONFIGURATIONS "")
macro(register_configuration NAME)
  list(APPEND CONFIGURATIONS "${NAME}")
endmacro()

macro(register_derived_artifact_execution_prefix NAME CONFIGURATION PREFIX)
  set("DERIVED_ARTIFACT_EXECUTION_PREFIX_${NAME}__${CONFIGURATION}" "${PREFIX}")
endmacro()

macro(register_existing_derived_artifact NAME SUFFIX)
  list(APPEND DERIVED_ARTIFACTS "${NAME}")
  set(DERIVED_ARTIFACT_${NAME}_IS_LOCAL No)

  foreach(ARTIFACT_CATEGORY IN LISTS ARTIFACT_CATEGORIES)
    foreach(ARTIFACT IN LISTS "ARTIFACTS_${ARTIFACT_CATEGORY}")
      foreach(CONFIGURATION IN LISTS CONFIGURATIONS)
        set(ARTIFACT_CONFIGURATION "${ARTIFACT_CONFIGURATION_${ARTIFACT_CATEGORY}__${ARTIFACT}}")
        category_to_path("${ARTIFACT_CATEGORY}" CATEGORY_PATH)
         if("${ARTIFACT_CONFIGURATION}" STREQUAL "" OR "${CONFIGURATION}" IN_LIST ARTIFACT_CONFIGURATION)
          # Register the output for this artifact for future use
          set("DERIVED_ARTIFACT_${NAME}_${ARTIFACT_CATEGORY}__${ARTIFACT}__${CONFIGURATION}" "share/revng/qa/${CATEGORY_PATH}/${CONFIGURATION}/${NAME}/${ARTIFACT}${SUFFIX}")
        endif()
      endforeach()
    endforeach()
  endforeach()

endmacro()

set(EXISTING_DERIVED_ARTIFACTS_CMAKE "${CMAKE_BINARY_DIR}/ExistingDerivedArtifacts.cmake")
file(WRITE "${EXISTING_DERIVED_ARTIFACTS_CMAKE}" "#\n# This file is automatically generated, do not edit\n#\n\n")
install(FILES "${EXISTING_DERIVED_ARTIFACTS_CMAKE}" DESTINATION share/revng/qa/cmake/derived-artifacts RENAME "${CMAKE_PROJECT_NAME}.cmake")

option(REVNG_QA_ENABLE_DERIVED_ARTIFACTS "Enable register_derived_artifact" ON)
macro(register_derived_artifact FROM_ARTIFACTS NAME SUFFIX TYPE)
  register_existing_derived_artifact("${NAME}" "${SUFFIX}")
  file(APPEND "${EXISTING_DERIVED_ARTIFACTS_CMAKE}" "register_existing_derived_artifact(\"${NAME}\" \"${SUFFIX}\")\n")
  set(DERIVED_ARTIFACT_${NAME}_IS_LOCAL Yes)

  # Check all the inputs exists
  foreach(FROM_ARTIFACT ${FROM_ARTIFACTS})
    if(NOT "${FROM_ARTIFACT}" STREQUAL "sources")
      set(FOUND No)
      foreach(DERIVED_ARTIFACT IN LISTS DERIVED_ARTIFACTS)
        if("${FROM_ARTIFACT}" STREQUAL "${DERIVED_ARTIFACT}")
          set(FOUND Yes)
          break()
        endif()
      endforeach()

      if(NOT "${FOUND}")
        message(FATAL_ERROR "Couldn't find source artifact ${FROM_ARTIFACT}")
      endif()

    endif()
  endforeach()

  foreach(ARTIFACT_CATEGORY IN LISTS ARTIFACT_CATEGORIES)
    foreach(ARTIFACT IN LISTS "ARTIFACTS_${ARTIFACT_CATEGORY}")
      foreach(CONFIGURATION IN LISTS CONFIGURATIONS)
        set(ARTIFACT_CONFIGURATION "${ARTIFACT_CONFIGURATION_${ARTIFACT_CATEGORY}__${ARTIFACT}}")
        category_to_path("${ARTIFACT_CATEGORY}" CATEGORY_PATH)
         if("${ARTIFACT_CONFIGURATION}" STREQUAL "" OR "${CONFIGURATION}" IN_LIST ARTIFACT_CONFIGURATION)
          # Get the input file, sources is special
          set(INPUTS "")
          foreach(FROM_ARTIFACT ${FROM_ARTIFACTS})
            if("${FROM_ARTIFACT}" STREQUAL "sources")
               if("${ARTIFACT_CONFIGURATION}" STREQUAL "")
                set(INPUT "${ARTIFACT_SOURCES_${ARTIFACT_CATEGORY}__${ARTIFACT}__}")
              else()
                set(INPUT "${ARTIFACT_SOURCES_${ARTIFACT_CATEGORY}__${ARTIFACT}__${CONFIGURATION}}")
              endif()
              add_prefix("${CMAKE_SOURCE_DIR}/" "${INPUT}" INPUT)
            elseif(NOT DERIVED_ARTIFACT_${FROM_ARTIFACT}_IS_LOCAL)
              set(INPUT "${DERIVED_ARTIFACT_${FROM_ARTIFACT}_${ARTIFACT_CATEGORY}__${ARTIFACT}__${CONFIGURATION}}")
              add_prefix("${CMAKE_INSTALL_PREFIX}/" "${INPUT}" INPUT)
            else()
              set(INPUT "${DERIVED_ARTIFACT_${FROM_ARTIFACT}_${ARTIFACT_CATEGORY}__${ARTIFACT}__${CONFIGURATION}}")
              add_prefix("${CMAKE_BINARY_DIR}/" "${INPUT}" INPUT)
            endif()
            list(APPEND INPUTS "${INPUT}")
          endforeach()

          # Generate the output path
          set(INSTALL_PATH "share/revng/qa/${CATEGORY_PATH}/${CONFIGURATION}/${NAME}")

          # Register the output for this artifact for future use
          set(OUTPUT "${CMAKE_BINARY_DIR}/${DERIVED_ARTIFACT_${NAME}_${ARTIFACT_CATEGORY}__${ARTIFACT}__${CONFIGURATION}}")
          get_filename_component(OUTPUT_DIR "${OUTPUT}" DIRECTORY)

          # Invoke the artifact handler
          set(DEPEND_ON "")
          set(COMMAND_TO_RUN "")
          artifact_handler("${ARTIFACT_CATEGORY}"
            "${INPUTS}"
            "${CONFIGURATION}"
            "${OUTPUT}"
            "${NAME}_${ARTIFACT_CATEGORY}__${ARTIFACT}__${CONFIGURATION}")

          if(NOT "${COMMAND_TO_RUN}" STREQUAL "")

            if(NOT REVNG_QA_ENABLE_DERIVED_ARTIFACTS)
              set(COMMAND_TO_RUN "touch ${OUTPUT}")
            endif()

            add_custom_command(OUTPUT "${OUTPUT}"
              COMMAND mkdir -p "${OUTPUT_DIR}"
              COMMAND ${COMMAND_TO_RUN}
              DEPENDS ${INPUTS}
              VERBATIM)

            foreach(FROM_ARTIFACT ${FROM_ARTIFACTS})
              if(NOT "${FROM_ARTIFACT}" STREQUAL "sources" AND DERIVED_ARTIFACT_${FROM_ARTIFACT}_IS_LOCAL)
                set(DEPEND_ON "${DEPEND_ON} compile-${FROM_ARTIFACT}_${ARTIFACT_CATEGORY}__${ARTIFACT}__${CONFIGURATION}")
              endif()
            endforeach()
            string(STRIP "${DEPEND_ON}" DEPEND_ON)

            add_custom_target(compile-${NAME}_${ARTIFACT_CATEGORY}__${ARTIFACT}__${CONFIGURATION} ALL DEPENDS ${OUTPUT} ${DEPEND_ON})

            if("${TYPE}" STREQUAL "PROGRAM")
              install(PROGRAMS "${OUTPUT}" DESTINATION "${INSTALL_PATH}")

              foreach(RUN IN LISTS ARTIFACT_RUNS_${ARTIFACT_CATEGORY}__${ARTIFACT})
                add_test(NAME "test_${NAME}_${CONFIGURATION}_${ARTIFACT_CATEGORY}__${ARTIFACT}__${RUN}"
                      COMMAND ${DERIVED_ARTIFACT_EXECUTION_PREFIX_${NAME}__${CONFIGURATION}} ${OUTPUT} ${ARTIFACT_RUNS_${ARTIFACT_CATEGORY}__${ARTIFACT}__${RUN}})
              endforeach()

            elseif("${TYPE}" STREQUAL "DIRECTORY")
              install(DIRECTORY "${OUTPUT}" DESTINATION "${INSTALL_PATH}")
            elseif("${TYPE}" STREQUAL "FILE")
              install(FILES "${OUTPUT}" DESTINATION "${INSTALL_PATH}")
            else()
              message(FATAL_ERROR "Unknown type ${TYPE}")
            endif()
          endif()

        endif()
      endforeach()
    endforeach()
  endforeach()
endmacro()
