# A CMake module that provides functions for using C++20 modules in Clang.

# Adds a library compiled with C++20 module support.
# `enabled` is a CMake variables that specifies if modules are enabled.
# If modules are disabled `add_module_library` falls back to creating a
# non-modular library.
#
# Usage:
#   add_module_library(<name> [sources...] MODULES [modules...] [IF enabled])
function(add_module_library name)
  cmake_parse_arguments(AML "" "IF" "MODULES" ${ARGN})
  set(sources ${AML_UNPARSED_ARGUMENTS})
  
  add_library(${name})
  set_target_properties(${name} PROPERTIES LINKER_LANGUAGE CXX)

  if (NOT ${${AML_IF}})
    # Create a non-modular library.
    target_sources(${name} PUBLIC ${sources})
    return()
  endif ()

  # Modules require C++20.
  target_compile_features(${name} PUBLIC cxx_std_20)

  # `std` is affected by CMake options and may be higher than C++20.
  get_target_property(std ${name} CXX_STANDARD)

  set(pcms)
  foreach (mod ${AML_MODULES})
    get_filename_component(pcm ${mod} NAME_WE)
    set(pcm ${pcm}.pcm)
    set(compile_options ${compile_options} -fmodule-file=${pcm})
    # Use an absolute path to prevent target_link_libraries prepending -l to it.
    set(pcms ${pcms} ${CMAKE_CURRENT_BINARY_DIR}/${pcm})
    add_custom_command(
      OUTPUT ${pcm}
      COMMAND ${CMAKE_CXX_COMPILER}
              -std=c++${std} -x c++-module --precompile -c
              -o ${pcm} ${CMAKE_CURRENT_SOURCE_DIR}/${mod}
              "-I$<JOIN:$<TARGET_PROPERTY:${name},INCLUDE_DIRECTORIES>,;-I>"
      # Required by the -I generator expression above.
      COMMAND_EXPAND_LISTS
      DEPENDS ${mod})
  endforeach ()

  # Add pcm files as sources to make sure they are built before the library.
  set(files)
  foreach (pcm ${pcms})
    get_filename_component(pcm_we ${pcm} NAME_WE)
    set(obj ${pcm_we}.o)
    # Use an absolute path to prevent target_link_libraries prepending -l to it.
    set(files ${files} ${pcm} ${CMAKE_CURRENT_BINARY_DIR}/${obj})
    add_custom_command(
      OUTPUT ${obj}
      COMMAND ${CMAKE_CXX_COMPILER} $<TARGET_PROPERTY:${name},COMPILE_OPTIONS> -c -o ${obj} ${pcm}
      DEPENDS ${pcm})
  endforeach ()
  target_sources(${name} PUBLIC ${files})

  #target_link_libraries(${name} ${pcms})
  # Propagate -fmodule-file=* to targets that link with this library.
  target_compile_options(${name} PUBLIC ${compile_options})
endfunction()
