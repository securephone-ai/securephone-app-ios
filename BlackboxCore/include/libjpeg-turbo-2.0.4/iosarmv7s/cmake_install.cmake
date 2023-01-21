# Install script for directory: /Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "/usr/local")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "Release")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "TRUE")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE SHARED_LIBRARY FILES
    "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7s/libturbojpeg.0.2.0.dylib"
    "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7s/libturbojpeg.0.dylib"
    "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7s/libturbojpeg.dylib"
    )
  foreach(file
      "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libturbojpeg.0.2.0.dylib"
      "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libturbojpeg.0.dylib"
      "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libturbojpeg.dylib"
      )
    if(EXISTS "${file}" AND
       NOT IS_SYMLINK "${file}")
      execute_process(COMMAND /usr/bin/install_name_tool
        -add_rpath "/usr/local/lib"
        "${file}")
      if(CMAKE_INSTALL_DO_STRIP)
        execute_process(COMMAND "/usr/bin/strip" "${file}")
      endif()
    endif()
  endforeach()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE EXECUTABLE FILES "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7s/tjbench")
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/tjbench" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/tjbench")
    if(CMAKE_INSTALL_DO_STRIP)
      execute_process(COMMAND "/usr/bin/strip" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/tjbench")
    endif()
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7s/libturbojpeg.a")
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libturbojpeg.a" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libturbojpeg.a")
    execute_process(COMMAND "/usr/bin/ranlib" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libturbojpeg.a")
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include" TYPE FILE FILES "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/turbojpeg.h")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7s/libjpeg.a")
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libjpeg.a" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libjpeg.a")
    execute_process(COMMAND "/usr/bin/ranlib" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libjpeg.a")
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE EXECUTABLE FILES "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7s/rdjpgcom")
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/rdjpgcom" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/rdjpgcom")
    if(CMAKE_INSTALL_DO_STRIP)
      execute_process(COMMAND "/usr/bin/strip" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/rdjpgcom")
    endif()
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE EXECUTABLE FILES "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7s/wrjpgcom")
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/wrjpgcom" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/wrjpgcom")
    if(CMAKE_INSTALL_DO_STRIP)
      execute_process(COMMAND "/usr/bin/strip" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/wrjpgcom")
    endif()
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/share/doc/libjpeg-turbo" TYPE FILE FILES
    "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/README.ijg"
    "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/README.md"
    "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/example.txt"
    "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/tjexample.c"
    "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/libjpeg.txt"
    "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/structure.txt"
    "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/usage.txt"
    "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/wizard.txt"
    "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/LICENSE.md"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/share/man/man1" TYPE FILE FILES
    "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/cjpeg.1"
    "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/djpeg.1"
    "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/jpegtran.1"
    "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/rdjpgcom.1"
    "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/wrjpgcom.1"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/pkgconfig" TYPE FILE FILES
    "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7s/pkgscripts/libjpeg.pc"
    "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7s/pkgscripts/libturbojpeg.pc"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include" TYPE FILE FILES
    "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7s/jconfig.h"
    "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/jerror.h"
    "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/jmorecfg.h"
    "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/jpeglib.h"
    )
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for each subdirectory.
  include("/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7s/simd/cmake_install.cmake")
  include("/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7s/sharedlib/cmake_install.cmake")
  include("/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7s/md5/cmake_install.cmake")

endif()

if(CMAKE_INSTALL_COMPONENT)
  set(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INSTALL_COMPONENT}.txt")
else()
  set(CMAKE_INSTALL_MANIFEST "install_manifest.txt")
endif()

string(REPLACE ";" "\n" CMAKE_INSTALL_MANIFEST_CONTENT
       "${CMAKE_INSTALL_MANIFEST_FILES}")
file(WRITE "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7s/${CMAKE_INSTALL_MANIFEST}"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
