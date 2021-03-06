# Copyright (c) 2016 Alain Martin
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


function(jucer_project_begin project_name)

  project(${project_name})
  set(JUCER_PROJECT_NAME ${project_name} PARENT_SCOPE)

  list(FIND ARGN "PROJECT_TYPE" project_type_tag_index)
  if(project_type_tag_index EQUAL -1)
    message(FATAL_ERROR "Missing PROJECT_TYPE argument")
  endif()

  set(project_type_descs "GUI Application" "Console Application")

  foreach(element ${ARGN})
    if(NOT DEFINED tag)
      set(tag ${element})
    else()
      set(value ${element})

      if(tag STREQUAL "PROJECT_VERSION")
        set(JUCER_PROJECT_VERSION "${value}" PARENT_SCOPE)
        __version_to_hex("${value}" hex_value)
        set(JUCER_PROJECT_VERSION_AS_HEX "${hex_value}" PARENT_SCOPE)
      elseif(tag STREQUAL "PROJECT_TYPE")
        list(FIND project_type_descs "${value}" project_type_index)
        if(project_type_index EQUAL -1)
          message(FATAL_ERROR "Unsupported project type: \"${project_type_desc}\"\n"
            "Supported project types: ${project_type_descs}"
          )
        endif()
        set(project_types "guiapp" "consoleapp")
        list(GET project_types ${project_type_index} JUCER_PROJECT_TYPE)
        set(JUCER_PROJECT_TYPE ${JUCER_PROJECT_TYPE} PARENT_SCOPE)
      else()
        message(FATAL_ERROR "Unsupported project setting: ${tag}")
      endif()

      unset(tag)
    endif()
  endforeach()

endfunction()


function(jucer_project_files source_group_name)

  string(REPLACE "/" "\\" source_group_name ${source_group_name})
  source_group(${source_group_name} FILES ${ARGN})

  list(APPEND JUCER_PROJECT_SOURCES ${ARGN})
  set(JUCER_PROJECT_SOURCES ${JUCER_PROJECT_SOURCES} PARENT_SCOPE)

endfunction()


function(jucer_project_resources source_group_name)

  string(REPLACE "/" "\\" source_group_name ${source_group_name})
  source_group(${source_group_name} FILES ${ARGN})

  list(APPEND JUCER_PROJECT_RESOURCES ${ARGN})
  set(JUCER_PROJECT_RESOURCES ${JUCER_PROJECT_RESOURCES} PARENT_SCOPE)

endfunction()


function(jucer_project_module module_name PATH_TAG module_path)

  list(APPEND JUCER_PROJECT_MODULES ${module_name})
  set(JUCER_PROJECT_MODULES ${JUCER_PROJECT_MODULES} PARENT_SCOPE)

  list(APPEND JUCER_PROJECT_INCLUDE_DIRS "${module_path}")
  set(JUCER_PROJECT_INCLUDE_DIRS ${JUCER_PROJECT_INCLUDE_DIRS} PARENT_SCOPE)

  get_filename_component(objcxx_module_file
    "${module_path}/${module_name}/${module_name}.mm" ABSOLUTE
  )
  if(APPLE AND EXISTS "${objcxx_module_file}")
    set(extension "mm")
  else()
    set(extension "cpp")
  endif()
  configure_file("${JUCE.cmake_ROOT}/cmake/ModuleWrapper.cpp"
    "JuceLibraryCode/${module_name}.${extension}"
  )
  list(APPEND JUCER_PROJECT_SOURCES
    "${CMAKE_CURRENT_BINARY_DIR}/JuceLibraryCode/${module_name}.${extension}"
  )
  set(JUCER_PROJECT_SOURCES ${JUCER_PROJECT_SOURCES} PARENT_SCOPE)

  list(APPEND JUCER_CONFIG_FLAGS ${ARGN})
  set(JUCER_CONFIG_FLAGS ${JUCER_CONFIG_FLAGS} PARENT_SCOPE)

  set(module_header_file "${module_path}/${module_name}/${module_name}.h")

  file(STRINGS "${module_header_file}" osx_frameworks_line REGEX "OSXFrameworks:")
  string(REPLACE "OSXFrameworks:" "" osx_frameworks_line "${osx_frameworks_line}")
  string(REPLACE " " ";" osx_frameworks "${osx_frameworks_line}")
  list(APPEND JUCER_PROJECT_OSX_FRAMEWORKS ${osx_frameworks})
  set(JUCER_PROJECT_OSX_FRAMEWORKS ${JUCER_PROJECT_OSX_FRAMEWORKS} PARENT_SCOPE)

  file(GLOB_RECURSE browsable_files "${module_path}/${module_name}/*")
  foreach(file_path ${browsable_files})
    get_filename_component(file_dir "${file_path}" DIRECTORY)
    string(REPLACE "${module_path}" "" rel_file_dir "${file_dir}")
    string(REPLACE "/" "\\" sub_group_name "${rel_file_dir}")
    source_group("Juce Modules${sub_group_name}" FILES "${file_path}")
  endforeach()
  list(APPEND JUCER_PROJECT_BROWSABLE_FILES ${browsable_files})
  set(JUCER_PROJECT_BROWSABLE_FILES ${JUCER_PROJECT_BROWSABLE_FILES} PARENT_SCOPE)

endfunction()


function(jucer_project_end)

  foreach(module_name ${JUCER_PROJECT_MODULES})
    string(CONCAT module_available_defines
      "${module_available_defines}"
      "#define JUCE_MODULE_AVAILABLE_${module_name} 1\n"
    )
  endforeach()
  foreach(element ${JUCER_CONFIG_FLAGS})
    if(NOT DEFINED flag_name)
      set(flag_name ${element})
    else()
      set(flag_value ${element})

      string(CONCAT config_flags_defines
        "${config_flags_defines}" "#ifndef    ${flag_name}\n"
      )
      if(flag_value)
        string(CONCAT config_flags_defines
          "${config_flags_defines}" " #define   ${flag_name} 1\n"
        )
      else()
        string(CONCAT config_flags_defines
          "${config_flags_defines}" " #define   ${flag_name} 0\n"
        )
      endif()
      string(CONCAT config_flags_defines "${config_flags_defines}" "#endif\n\n")

      if(flag_name STREQUAL "JUCE_PLUGINHOST_AU")
        if(flag_value)
          list(APPEND JUCER_PROJECT_OSX_FRAMEWORKS "AudioUnit" "CoreAudioKit")
        endif()
      endif()

      unset(flag_name)
    endif()
  endforeach()
  configure_file("${JUCE.cmake_ROOT}/cmake/AppConfig.h" "JuceLibraryCode/AppConfig.h")

  list(LENGTH JUCER_PROJECT_RESOURCES resources_count)
  if(resources_count GREATER 0)
    message("Building BinaryDataBuilder for ${JUCER_PROJECT_NAME}")
    try_compile(BinaryDataBuilder
      "${JUCE.cmake_ROOT}/cmake/BinaryDataBuilder/_build"
      "${JUCE.cmake_ROOT}/cmake/BinaryDataBuilder"
      BinaryDataBuilder install
      CMAKE_FLAGS "-DCMAKE_INSTALL_PREFIX=${CMAKE_CURRENT_BINARY_DIR}"
    )
    if(NOT BinaryDataBuilder)
      message(FATAL_ERROR "Failed to build BinaryDataBuilder")
    endif()
    message("BinaryDataBuilder has been successfully built")
    list(APPEND BinaryDataBuilder_args "${CMAKE_CURRENT_BINARY_DIR}/JuceLibraryCode/")
    foreach(element ${JUCER_PROJECT_RESOURCES})
      list(APPEND BinaryDataBuilder_args "${CMAKE_CURRENT_LIST_DIR}/${element}")
    endforeach()
    execute_process(
      COMMAND "${CMAKE_CURRENT_BINARY_DIR}/BinaryDataBuilder/BinaryDataBuilder"
      ${BinaryDataBuilder_args}
      OUTPUT_VARIABLE binary_data_filenames
      RESULT_VARIABLE BinaryDataBuilder_return_code
    )
    if(NOT BinaryDataBuilder_return_code EQUAL 0)
      message(FATAL_ERROR "Error when executing BinaryDataBuilder")
    endif()
    foreach(filename ${binary_data_filenames})
      list(APPEND JUCER_PROJECT_SOURCES
        "${CMAKE_CURRENT_BINARY_DIR}/JuceLibraryCode/${filename}"
      )
    endforeach()
    set(binary_data_include "#include \"BinaryData.h\"")
  else()
    set(binary_data_include "")
  endif()

  foreach(module_name ${JUCER_PROJECT_MODULES})
    string(CONCAT modules_includes
      "${modules_includes}"
      "#include <${module_name}/${module_name}.h>\n"
    )
  endforeach()
  configure_file("${JUCE.cmake_ROOT}/cmake/JuceHeader.h" "JuceLibraryCode/JuceHeader.h")

  source_group("Juce Library Code"
    REGULAR_EXPRESSION "${CMAKE_CURRENT_BINARY_DIR}/JuceLibraryCode/*"
  )

  string(REGEX REPLACE "[^A-Za-z0-9_.+-]" "_" target_name "${JUCER_PROJECT_NAME}")

  add_executable(${target_name}
    ${JUCER_PROJECT_SOURCES}
    ${JUCER_PROJECT_RESOURCES}
    "${CMAKE_CURRENT_BINARY_DIR}/JuceLibraryCode/AppConfig.h"
    "${CMAKE_CURRENT_BINARY_DIR}/JuceLibraryCode/JuceHeader.h"
    ${JUCER_PROJECT_BROWSABLE_FILES}
  )

  if(JUCER_PROJECT_TYPE STREQUAL "guiapp")
    set_target_properties(${target_name} PROPERTIES MACOSX_BUNDLE TRUE)
    set_target_properties(${target_name} PROPERTIES WIN32_EXECUTABLE TRUE)
  endif()

  set_target_properties(${target_name} PROPERTIES OUTPUT_NAME "${JUCER_PROJECT_NAME}")

  set_source_files_properties(
    ${JUCER_PROJECT_BROWSABLE_FILES}
    ${JUCER_PROJECT_RESOURCES}
    PROPERTIES HEADER_FILE_ONLY TRUE
  )

  target_include_directories(${target_name} PRIVATE
    "${CMAKE_CURRENT_BINARY_DIR}/JuceLibraryCode"
    ${JUCER_PROJECT_INCLUDE_DIRS}
  )

  if(APPLE)
    target_compile_options(${target_name} PRIVATE -std=c++11)
    target_compile_definitions(${target_name} PRIVATE $<$<CONFIG:Debug>:_DEBUG>)

    list(REMOVE_DUPLICATES JUCER_PROJECT_OSX_FRAMEWORKS)
    foreach(framework_name ${JUCER_PROJECT_OSX_FRAMEWORKS})
      find_library(${framework_name}_framework ${framework_name})
      target_link_libraries(${target_name} "${${framework_name}_framework}")
    endforeach()
  endif()

endfunction()


function(__dec_to_hex dec_value out_hex_value)

  if(dec_value EQUAL 0)
    set(${out_hex_value} "0x0" PARENT_SCOPE)
  else()
    while(dec_value GREATER 0)
      math(EXPR hex_unit "${dec_value} & 15")
      if(hex_unit LESS 10)
        set(hex_char ${hex_unit})
      else()
        math(EXPR hex_unit "${hex_unit} + 87")
        string(ASCII ${hex_unit} hex_char)
      endif()
      set(hex_value "${hex_char}${hex_value}")
      math(EXPR dec_value "${dec_value} >> 4")
    endwhile()
    set(${out_hex_value} "0x${hex_value}" PARENT_SCOPE)
  endif()

endfunction()


function(__version_to_hex version out_hex_value)

  string(REPLACE "." ";" segments "${version}")
  list(LENGTH segments segments_size)
  while(segments_size LESS 3)
    list(APPEND segments 0)
    math(EXPR segments_size "${segments_size} + 1")
  endwhile()
  list(GET segments 0 major)
  list(GET segments 1 minor)
  list(GET segments 2 patch)
  math(EXPR dec_value "(${major} << 16) + (${minor} << 8) + ${patch}")
  if(segments_size GREATER 3)
    list(GET segments 3 revision)
    math(EXPR dec_value "${dec_value} << 8 + ${revision}")
  endif()

  __dec_to_hex("${dec_value}" hex_value)
  set(${out_hex_value} "${hex_value}" PARENT_SCOPE)

endfunction()
