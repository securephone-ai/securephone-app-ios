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
CMAKE_BINARY_DIR = "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7"

# Include any dependencies generated for this target.
include sharedlib/CMakeFiles/djpeg.dir/depend.make

# Include the progress variables for this target.
include sharedlib/CMakeFiles/djpeg.dir/progress.make

# Include the compile flags for this target's objects.
include sharedlib/CMakeFiles/djpeg.dir/flags.make

sharedlib/CMakeFiles/djpeg.dir/__/djpeg.c.o: sharedlib/CMakeFiles/djpeg.dir/flags.make
sharedlib/CMakeFiles/djpeg.dir/__/djpeg.c.o: /Users/Valerio/Project/spe2eeapp/iOS/Spe2ee\ copy/src/libjpeg-turbo-2.0.4/djpeg.c
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir="/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/CMakeFiles" --progress-num=$(CMAKE_PROGRESS_1) "Building C object sharedlib/CMakeFiles/djpeg.dir/__/djpeg.c.o"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -o CMakeFiles/djpeg.dir/__/djpeg.c.o   -c "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/djpeg.c"

sharedlib/CMakeFiles/djpeg.dir/__/djpeg.c.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/djpeg.dir/__/djpeg.c.i"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -E "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/djpeg.c" > CMakeFiles/djpeg.dir/__/djpeg.c.i

sharedlib/CMakeFiles/djpeg.dir/__/djpeg.c.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/djpeg.dir/__/djpeg.c.s"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -S "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/djpeg.c" -o CMakeFiles/djpeg.dir/__/djpeg.c.s

sharedlib/CMakeFiles/djpeg.dir/__/cdjpeg.c.o: sharedlib/CMakeFiles/djpeg.dir/flags.make
sharedlib/CMakeFiles/djpeg.dir/__/cdjpeg.c.o: /Users/Valerio/Project/spe2eeapp/iOS/Spe2ee\ copy/src/libjpeg-turbo-2.0.4/cdjpeg.c
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir="/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/CMakeFiles" --progress-num=$(CMAKE_PROGRESS_2) "Building C object sharedlib/CMakeFiles/djpeg.dir/__/cdjpeg.c.o"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -o CMakeFiles/djpeg.dir/__/cdjpeg.c.o   -c "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/cdjpeg.c"

sharedlib/CMakeFiles/djpeg.dir/__/cdjpeg.c.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/djpeg.dir/__/cdjpeg.c.i"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -E "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/cdjpeg.c" > CMakeFiles/djpeg.dir/__/cdjpeg.c.i

sharedlib/CMakeFiles/djpeg.dir/__/cdjpeg.c.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/djpeg.dir/__/cdjpeg.c.s"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -S "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/cdjpeg.c" -o CMakeFiles/djpeg.dir/__/cdjpeg.c.s

sharedlib/CMakeFiles/djpeg.dir/__/rdcolmap.c.o: sharedlib/CMakeFiles/djpeg.dir/flags.make
sharedlib/CMakeFiles/djpeg.dir/__/rdcolmap.c.o: /Users/Valerio/Project/spe2eeapp/iOS/Spe2ee\ copy/src/libjpeg-turbo-2.0.4/rdcolmap.c
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir="/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/CMakeFiles" --progress-num=$(CMAKE_PROGRESS_3) "Building C object sharedlib/CMakeFiles/djpeg.dir/__/rdcolmap.c.o"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -o CMakeFiles/djpeg.dir/__/rdcolmap.c.o   -c "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/rdcolmap.c"

sharedlib/CMakeFiles/djpeg.dir/__/rdcolmap.c.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/djpeg.dir/__/rdcolmap.c.i"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -E "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/rdcolmap.c" > CMakeFiles/djpeg.dir/__/rdcolmap.c.i

sharedlib/CMakeFiles/djpeg.dir/__/rdcolmap.c.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/djpeg.dir/__/rdcolmap.c.s"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -S "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/rdcolmap.c" -o CMakeFiles/djpeg.dir/__/rdcolmap.c.s

sharedlib/CMakeFiles/djpeg.dir/__/rdswitch.c.o: sharedlib/CMakeFiles/djpeg.dir/flags.make
sharedlib/CMakeFiles/djpeg.dir/__/rdswitch.c.o: /Users/Valerio/Project/spe2eeapp/iOS/Spe2ee\ copy/src/libjpeg-turbo-2.0.4/rdswitch.c
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir="/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/CMakeFiles" --progress-num=$(CMAKE_PROGRESS_4) "Building C object sharedlib/CMakeFiles/djpeg.dir/__/rdswitch.c.o"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -o CMakeFiles/djpeg.dir/__/rdswitch.c.o   -c "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/rdswitch.c"

sharedlib/CMakeFiles/djpeg.dir/__/rdswitch.c.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/djpeg.dir/__/rdswitch.c.i"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -E "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/rdswitch.c" > CMakeFiles/djpeg.dir/__/rdswitch.c.i

sharedlib/CMakeFiles/djpeg.dir/__/rdswitch.c.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/djpeg.dir/__/rdswitch.c.s"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -S "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/rdswitch.c" -o CMakeFiles/djpeg.dir/__/rdswitch.c.s

sharedlib/CMakeFiles/djpeg.dir/__/wrgif.c.o: sharedlib/CMakeFiles/djpeg.dir/flags.make
sharedlib/CMakeFiles/djpeg.dir/__/wrgif.c.o: /Users/Valerio/Project/spe2eeapp/iOS/Spe2ee\ copy/src/libjpeg-turbo-2.0.4/wrgif.c
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir="/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/CMakeFiles" --progress-num=$(CMAKE_PROGRESS_5) "Building C object sharedlib/CMakeFiles/djpeg.dir/__/wrgif.c.o"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -o CMakeFiles/djpeg.dir/__/wrgif.c.o   -c "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/wrgif.c"

sharedlib/CMakeFiles/djpeg.dir/__/wrgif.c.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/djpeg.dir/__/wrgif.c.i"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -E "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/wrgif.c" > CMakeFiles/djpeg.dir/__/wrgif.c.i

sharedlib/CMakeFiles/djpeg.dir/__/wrgif.c.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/djpeg.dir/__/wrgif.c.s"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -S "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/wrgif.c" -o CMakeFiles/djpeg.dir/__/wrgif.c.s

sharedlib/CMakeFiles/djpeg.dir/__/wrppm.c.o: sharedlib/CMakeFiles/djpeg.dir/flags.make
sharedlib/CMakeFiles/djpeg.dir/__/wrppm.c.o: /Users/Valerio/Project/spe2eeapp/iOS/Spe2ee\ copy/src/libjpeg-turbo-2.0.4/wrppm.c
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir="/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/CMakeFiles" --progress-num=$(CMAKE_PROGRESS_6) "Building C object sharedlib/CMakeFiles/djpeg.dir/__/wrppm.c.o"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -o CMakeFiles/djpeg.dir/__/wrppm.c.o   -c "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/wrppm.c"

sharedlib/CMakeFiles/djpeg.dir/__/wrppm.c.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/djpeg.dir/__/wrppm.c.i"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -E "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/wrppm.c" > CMakeFiles/djpeg.dir/__/wrppm.c.i

sharedlib/CMakeFiles/djpeg.dir/__/wrppm.c.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/djpeg.dir/__/wrppm.c.s"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -S "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/wrppm.c" -o CMakeFiles/djpeg.dir/__/wrppm.c.s

sharedlib/CMakeFiles/djpeg.dir/__/wrbmp.c.o: sharedlib/CMakeFiles/djpeg.dir/flags.make
sharedlib/CMakeFiles/djpeg.dir/__/wrbmp.c.o: /Users/Valerio/Project/spe2eeapp/iOS/Spe2ee\ copy/src/libjpeg-turbo-2.0.4/wrbmp.c
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir="/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/CMakeFiles" --progress-num=$(CMAKE_PROGRESS_7) "Building C object sharedlib/CMakeFiles/djpeg.dir/__/wrbmp.c.o"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -o CMakeFiles/djpeg.dir/__/wrbmp.c.o   -c "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/wrbmp.c"

sharedlib/CMakeFiles/djpeg.dir/__/wrbmp.c.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/djpeg.dir/__/wrbmp.c.i"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -E "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/wrbmp.c" > CMakeFiles/djpeg.dir/__/wrbmp.c.i

sharedlib/CMakeFiles/djpeg.dir/__/wrbmp.c.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/djpeg.dir/__/wrbmp.c.s"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -S "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/wrbmp.c" -o CMakeFiles/djpeg.dir/__/wrbmp.c.s

sharedlib/CMakeFiles/djpeg.dir/__/wrtarga.c.o: sharedlib/CMakeFiles/djpeg.dir/flags.make
sharedlib/CMakeFiles/djpeg.dir/__/wrtarga.c.o: /Users/Valerio/Project/spe2eeapp/iOS/Spe2ee\ copy/src/libjpeg-turbo-2.0.4/wrtarga.c
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir="/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/CMakeFiles" --progress-num=$(CMAKE_PROGRESS_8) "Building C object sharedlib/CMakeFiles/djpeg.dir/__/wrtarga.c.o"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -o CMakeFiles/djpeg.dir/__/wrtarga.c.o   -c "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/wrtarga.c"

sharedlib/CMakeFiles/djpeg.dir/__/wrtarga.c.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/djpeg.dir/__/wrtarga.c.i"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -E "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/wrtarga.c" > CMakeFiles/djpeg.dir/__/wrtarga.c.i

sharedlib/CMakeFiles/djpeg.dir/__/wrtarga.c.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/djpeg.dir/__/wrtarga.c.s"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -S "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/wrtarga.c" -o CMakeFiles/djpeg.dir/__/wrtarga.c.s

# Object files for target djpeg
djpeg_OBJECTS = \
"CMakeFiles/djpeg.dir/__/djpeg.c.o" \
"CMakeFiles/djpeg.dir/__/cdjpeg.c.o" \
"CMakeFiles/djpeg.dir/__/rdcolmap.c.o" \
"CMakeFiles/djpeg.dir/__/rdswitch.c.o" \
"CMakeFiles/djpeg.dir/__/wrgif.c.o" \
"CMakeFiles/djpeg.dir/__/wrppm.c.o" \
"CMakeFiles/djpeg.dir/__/wrbmp.c.o" \
"CMakeFiles/djpeg.dir/__/wrtarga.c.o"

# External object files for target djpeg
djpeg_EXTERNAL_OBJECTS =

djpeg: sharedlib/CMakeFiles/djpeg.dir/__/djpeg.c.o
djpeg: sharedlib/CMakeFiles/djpeg.dir/__/cdjpeg.c.o
djpeg: sharedlib/CMakeFiles/djpeg.dir/__/rdcolmap.c.o
djpeg: sharedlib/CMakeFiles/djpeg.dir/__/rdswitch.c.o
djpeg: sharedlib/CMakeFiles/djpeg.dir/__/wrgif.c.o
djpeg: sharedlib/CMakeFiles/djpeg.dir/__/wrppm.c.o
djpeg: sharedlib/CMakeFiles/djpeg.dir/__/wrbmp.c.o
djpeg: sharedlib/CMakeFiles/djpeg.dir/__/wrtarga.c.o
djpeg: sharedlib/CMakeFiles/djpeg.dir/build.make
djpeg: libjpeg.62.3.0.dylib
djpeg: sharedlib/CMakeFiles/djpeg.dir/link.txt
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --bold --progress-dir="/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/CMakeFiles" --progress-num=$(CMAKE_PROGRESS_9) "Linking C executable ../djpeg"
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && $(CMAKE_COMMAND) -E cmake_link_script CMakeFiles/djpeg.dir/link.txt --verbose=$(VERBOSE)

# Rule to build all files generated by this target.
sharedlib/CMakeFiles/djpeg.dir/build: djpeg

.PHONY : sharedlib/CMakeFiles/djpeg.dir/build

sharedlib/CMakeFiles/djpeg.dir/clean:
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" && $(CMAKE_COMMAND) -P CMakeFiles/djpeg.dir/cmake_clean.cmake
.PHONY : sharedlib/CMakeFiles/djpeg.dir/clean

sharedlib/CMakeFiles/djpeg.dir/depend:
	cd "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7" && $(CMAKE_COMMAND) -E cmake_depends "Unix Makefiles" "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4" "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/src/libjpeg-turbo-2.0.4/sharedlib" "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7" "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib" "/Users/Valerio/Project/spe2eeapp/iOS/Spe2ee copy/libs/libjpeg-turbo-2.0.4/ARMv7/sharedlib/CMakeFiles/djpeg.dir/DependInfo.cmake" --color=$(COLOR)
.PHONY : sharedlib/CMakeFiles/djpeg.dir/depend
