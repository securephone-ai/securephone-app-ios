# CMAKE generated file: DO NOT EDIT!
# Generated by "Unix Makefiles" Generator, CMake Version 3.11

# Delete rule output on recipe failure.
.DELETE_ON_ERROR:


#=============================================================================
# Special targets provided by cmake.

# Disable implicit rules so canonical targets will work.
.SUFFIXES:


# Remove some rules from gmake that .SUFFIXES does not remove.
SUFFIXES =

.SUFFIXES: .hpux_make_needs_suffix_list


# Suppress display of executed commands.
$(VERBOSE).SILENT:


# A target that is always out of date.
cmake_force:

.PHONY : cmake_force

#=============================================================================
# Set environment variables for the build.

# The shell in which to execute make rules.
SHELL = /bin/sh

# The CMake executable.
CMAKE_COMMAND = /usr/local/Cellar/cmake/3.11.1/bin/cmake

# The command to remove a file.
RM = /usr/local/Cellar/cmake/3.11.1/bin/cmake -E remove -f

# Escaping for special characters.
EQUALS = =

# The top-level source directory on which CMake was run.
CMAKE_SOURCE_DIR = "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4"

# The top-level build directory on which CMake was run.
CMAKE_BINARY_DIR = "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv8-x64"

# Include any dependencies generated for this target.
include sharedlib/CMakeFiles/jcstest.dir/depend.make

# Include the progress variables for this target.
include sharedlib/CMakeFiles/jcstest.dir/progress.make

# Include the compile flags for this target's objects.
include sharedlib/CMakeFiles/jcstest.dir/flags.make

sharedlib/CMakeFiles/jcstest.dir/__/jcstest.c.o: sharedlib/CMakeFiles/jcstest.dir/flags.make
sharedlib/CMakeFiles/jcstest.dir/__/jcstest.c.o: /Users/Valerio/Project/spe2eeapp/iOS/Spe2ee\ copy/src/libjpeg-turbo-2.0.4/jcstest.c
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir="/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv8-x64/CMakeFiles" --progress-num=$(CMAKE_PROGRESS_1) "Building C object sharedlib/CMakeFiles/jcstest.dir/__/jcstest.c.o"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv8-x64/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -o CMakeFiles/jcstest.dir/__/jcstest.c.o   -c "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/jcstest.c"

sharedlib/CMakeFiles/jcstest.dir/__/jcstest.c.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/jcstest.dir/__/jcstest.c.i"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv8-x64/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -E "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/jcstest.c" > CMakeFiles/jcstest.dir/__/jcstest.c.i

sharedlib/CMakeFiles/jcstest.dir/__/jcstest.c.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/jcstest.dir/__/jcstest.c.s"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv8-x64/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -S "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/jcstest.c" -o CMakeFiles/jcstest.dir/__/jcstest.c.s

# Object files for target jcstest
jcstest_OBJECTS = \
"CMakeFiles/jcstest.dir/__/jcstest.c.o"

# External object files for target jcstest
jcstest_EXTERNAL_OBJECTS =

jcstest: sharedlib/CMakeFiles/jcstest.dir/__/jcstest.c.o
jcstest: sharedlib/CMakeFiles/jcstest.dir/build.make
jcstest: libjpeg.62.3.0.dylib
jcstest: sharedlib/CMakeFiles/jcstest.dir/link.txt
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --bold --progress-dir="/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv8-x64/CMakeFiles" --progress-num=$(CMAKE_PROGRESS_2) "Linking C executable ../jcstest"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv8-x64/sharedlib" && $(CMAKE_COMMAND) -E cmake_link_script CMakeFiles/jcstest.dir/link.txt --verbose=$(VERBOSE)

# Rule to build all files generated by this target.
sharedlib/CMakeFiles/jcstest.dir/build: jcstest

.PHONY : sharedlib/CMakeFiles/jcstest.dir/build

sharedlib/CMakeFiles/jcstest.dir/clean:
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv8-x64/sharedlib" && $(CMAKE_COMMAND) -P CMakeFiles/jcstest.dir/cmake_clean.cmake
.PHONY : sharedlib/CMakeFiles/jcstest.dir/clean

sharedlib/CMakeFiles/jcstest.dir/depend:
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv8-x64" && $(CMAKE_COMMAND) -E cmake_depends "Unix Makefiles" "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4" "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/sharedlib" "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv8-x64" "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv8-x64/sharedlib" "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv8-x64/sharedlib/CMakeFiles/jcstest.dir/DependInfo.cmake" --color=$(COLOR)
.PHONY : sharedlib/CMakeFiles/jcstest.dir/depend
