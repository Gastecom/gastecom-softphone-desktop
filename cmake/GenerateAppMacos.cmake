################################################################################
#  GenerateFrameworks.cmake
#  Copyright (c) 2021-2023 Belledonne Communications SARL.
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program. If not, see <http://www.gnu.org/licenses/>.
#
################################################################################

cmake_policy(SET CMP0009 NEW) # Do not follow symlinks when doing file(GLOB_RECURSE)

include("${LINPHONESDK_DIR}/cmake/LinphoneSdkUtils.cmake")


linphone_sdk_convert_comma_separated_list_to_cmake_list("${LINPHONEAPP_MACOS_ARCHS}" _MACOS_ARCHS)
list(GET _MACOS_ARCHS 0 _FIRST_ARCH)

set(MAIN_INSTALL_DIR ${CMAKE_INSTALL_PREFIX}/${LINPHONEAPP_FOLDER})	#OUTPUT/macos

################################
# Create the desktop directory that will contain the merged content of all architectures
################################

execute_process(
	COMMAND "${CMAKE_COMMAND}" "-E" "remove_directory" "${MAIN_INSTALL_DIR}"
	COMMAND "${CMAKE_COMMAND}" "-E" "make_directory" "${MAIN_INSTALL_DIR}"
	COMMAND "${CMAKE_COMMAND}" "-E" "make_directory" "${MAIN_INSTALL_DIR}/${LINPHONEAPP_FOLDER}"
)

################################
# Copy outside folders that should be in .app package
################################
function( copy_outside_folders _ARCH)
# Prepare .app
	execute_process(COMMAND rsync -a --force "${MAIN_INSTALL_DIR}-${_ARCH}/Frameworks/" "${MAIN_INSTALL_DIR}-${_ARCH}/${CMAKE_INSTALL_LIBDIR}/")
	execute_process(COMMAND ${CMAKE_COMMAND} -E copy_directory "${MAIN_INSTALL_DIR}-${_ARCH}/include/" "${MAIN_INSTALL_DIR}-${_ARCH}/${CMAKE_INSTALL_INCLUDEDIR}/")
# move share
	execute_process(COMMAND ${CMAKE_COMMAND} -E copy_directory "${MAIN_INSTALL_DIR}-${_ARCH}/share/" "${MAIN_INSTALL_DIR}-${_ARCH}/${CMAKE_INSTALL_DATAROOTDIR}/")
# move mkspecs
	if(EXISTS "${MAIN_INSTALL_DIR}-${_ARCH}/mkspecs/")
		execute_process(COMMAND ${CMAKE_COMMAND} -E copy_directory "${MAIN_INSTALL_DIR}-${_ARCH}/mkspecs/" "${MAIN_INSTALL_DIR}-${_ARCH}/${CMAKE_INSTALL_DATAROOTDIR}/")
	endif()
endfunction()

foreach(_ARCH IN LISTS _MACOS_ARCHS)
	copy_outside_folders(${_ARCH})
endforeach()

################################
# Copy and merge content of all architectures in the desktop directory
################################
# Do not use copy_directory because of symlinks
execute_process(COMMAND rsync -a --force "${MAIN_INSTALL_DIR}-${_FIRST_ARCH}/" "${MAIN_INSTALL_DIR}" WORKING_DIRECTORY "${LINPHONEAPP_BUILD_DIR}")

################################
#####		MIX
################################
# Get all files in output
file(GLOB_RECURSE _BINARIES RELATIVE "${MAIN_INSTALL_DIR}-${_FIRST_ARCH}/" "${MAIN_INSTALL_DIR}-${_FIRST_ARCH}/*")

if(NOT ENABLE_FAT_BINARY)
	# Remove all .framework inputs from the result
	list(FILTER _BINARIES EXCLUDE REGEX ".*\\.framework.*")
endif()

foreach(_FILE IN LISTS _BINARIES)
	get_filename_component(ABSOLUTE_FILE "${MAIN_INSTALL_DIR}-${_FIRST_ARCH}/${_FILE}" ABSOLUTE)
	if(NOT IS_SYMLINK ${ABSOLUTE_FILE})
		# Check if lipo can detect an architecture
		execute_process(COMMAND lipo -archs "${MAIN_INSTALL_DIR}-${_FIRST_ARCH}/${_FILE}"
			OUTPUT_VARIABLE FILE_ARCHITECTURE
			OUTPUT_STRIP_TRAILING_WHITESPACE
			WORKING_DIRECTORY "${LINPHONEAPP_BUILD_DIR}"
			RESULT_VARIABLE _LIPO_RESULT
		)
		if(NOT _LIPO_RESULT EQUAL 0)
			message(WARNING "lipo failed for ${_FILE} (exit code ${_LIPO_RESULT})")
		endif()
		if(NOT "${FILE_ARCHITECTURE}" STREQUAL "")
			# There is at least one architecture : Use this candidate to mix with another architecture
			set(_ALL_ARCH_FILES)
			foreach(_ARCH IN LISTS _MACOS_ARCHS)
				list(APPEND _ALL_ARCH_FILES "${MAIN_INSTALL_DIR}-${_ARCH}/${_FILE}")
			endforeach()
			string(REPLACE ";" " " _ARCH_STRING "${_MACOS_ARCHS}")
			message(STATUS "Mixing ${_FILE} for archs [${_ARCH_STRING}]")
			execute_process(
				COMMAND "lipo" "-create" "-output" "${MAIN_INSTALL_DIR}/${_FILE}" ${_ALL_ARCH_FILES}
				WORKING_DIRECTORY "${LINPHONEAPP_BUILD_DIR}"
			)
		endif()
	endif()
endforeach()

set(_APP "${MAIN_INSTALL_DIR}/${LINPHONEAPP_APPLICATION_NAME}.app")
set(_MAIN_EXE "${_APP}/Contents/MacOS/${LINPHONEAPP_EXECUTABLE_NAME}")

file(REMOVE_RECURSE
	"${_APP}/Contents/Frameworks/cmake"
	"${_APP}/Contents/Frameworks/pkgconfig"
	"${_APP}/Contents/Resources/include"
)
file(GLOB _NON_DIST_LIBS "${_APP}/Contents/Frameworks/*.a")
if(_NON_DIST_LIBS)
	file(REMOVE ${_NON_DIST_LIBS})
endif()

if(LINPHONE_BUILDER_SIGNING_IDENTITY)
	execute_process(
		COMMAND bash "${LINPHONEAPP_SOURCE_DIR}/cmake/install/sign_macos_app.sh" "${LINPHONE_BUILDER_SIGNING_IDENTITY}" "${_APP}" "${LINPHONE_ENTITLEMENTS}" "${LINPHONEAPP_EXECUTABLE_NAME}"
		RESULT_VARIABLE _SIGN_RESULT
	)
	if(NOT _SIGN_RESULT EQUAL 0)
		message(FATAL_ERROR "codesign failed while signing ${_APP} (exit ${_SIGN_RESULT})")
	endif()
	execute_process(COMMAND codesign --verify --deep --strict --verbose=2 "${_APP}" RESULT_VARIABLE _VERIFY_RESULT)
	if(NOT _VERIFY_RESULT EQUAL 0)
		message(FATAL_ERROR "codesign --verify failed on ${_APP} (exit ${_VERIFY_RESULT})")
	endif()
else()
	execute_process(COMMAND codesign --force --deep --sign - "${MAIN_INSTALL_DIR}/${LINPHONEAPP_APPLICATION_NAME}.app")#If not code signed, app can crash because of APPLE on "Code Signature Invalid".
endif()

################################
#####		PACKAGE (DMG)
################################
if(ENABLE_APP_PACKAGING)
	set(_DMG_NAME "${LINPHONEAPP_APPLICATION_NAME}-${LINPHONEAPP_VERSION}-mac")
	set(_PKG_DIR "${MAIN_INSTALL_DIR}/Packages")
	set(_DMG_STAGE "${LINPHONEAPP_BUILD_DIR}/dmg-stage")

	file(REMOVE_RECURSE "${_DMG_STAGE}")
	file(MAKE_DIRECTORY "${_DMG_STAGE}")
	file(MAKE_DIRECTORY "${_PKG_DIR}")
	execute_process(COMMAND ditto "${_APP}" "${_DMG_STAGE}/${LINPHONEAPP_APPLICATION_NAME}.app")

	set(_CPACK_CONFIG "${LINPHONEAPP_BUILD_DIR}/CPackConfig-macos-universal.cmake")
	file(WRITE "${_CPACK_CONFIG}"
"set(CPACK_GENERATOR \"DragNDrop\")
set(CPACK_BINARY_DRAGNDROP ON)
set(CPACK_PACKAGE_NAME \"${LINPHONEAPP_APPLICATION_NAME}\")
set(CPACK_PACKAGE_VERSION \"${LINPHONEAPP_VERSION}\")
set(CPACK_PACKAGE_FILE_NAME \"${_DMG_NAME}\")
set(CPACK_PACKAGE_DESCRIPTION \"${LINPHONEAPP_APPLICATION_NAME}\")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY \"${LINPHONEAPP_APPLICATION_NAME}\")
set(CPACK_PACKAGE_INSTALL_DIRECTORY \"${LINPHONEAPP_APPLICATION_NAME}\")
set(CPACK_PACKAGE_EXECUTABLES \"${LINPHONEAPP_EXECUTABLE_NAME};${LINPHONEAPP_APPLICATION_NAME}\")
set(CPACK_COMPONENTS_GROUPING ALL_COMPONENTS_IN_ONE)
set(CPACK_MONOLITHIC_INSTALL TRUE)
set(CPACK_INSTALLED_DIRECTORIES \"${_DMG_STAGE};.\")
set(CPACK_DMG_VOLUME_NAME \"${_DMG_NAME}\")
set(CPACK_PACKAGE_DIRECTORY \"${_PKG_DIR}\")
")
	if(LINPHONE_DMG_BACKGROUND)
		file(APPEND "${_CPACK_CONFIG}" "set(CPACK_DMG_BACKGROUND_IMAGE \"${LINPHONE_DMG_BACKGROUND}\")\n")
	endif()
	if(LINPHONE_DMG_SCPT)
		file(APPEND "${_CPACK_CONFIG}" "set(CPACK_DMG_DS_STORE_SETUP_SCRIPT \"${LINPHONE_DMG_SCPT}\")\n")
	endif()
	if(LINPHONE_DMG_LICENSE)
		file(APPEND "${_CPACK_CONFIG}" "set(CPACK_RESOURCE_FILE_LICENSE \"${LINPHONE_DMG_LICENSE}\")\n")
		file(APPEND "${_CPACK_CONFIG}" "set(CPACK_RESOURCE_FILE_LICENSE_PROVIDED ON)\n")
		file(APPEND "${_CPACK_CONFIG}" "set(CPACK_DMG_SLA_USE_RESOURCE_FILE_LICENSE ON)\n")
	endif()
	if(LINPHONE_DMG_PREBUILD)
		file(APPEND "${_CPACK_CONFIG}" "set(CPACK_PRE_BUILD_SCRIPTS \"${LINPHONE_DMG_PREBUILD}\")\n")
	endif()

	execute_process(COMMAND cpack --config "${_CPACK_CONFIG}" RESULT_VARIABLE _CPACK_RESULT)
	if(NOT _CPACK_RESULT EQUAL 0)
		message(FATAL_ERROR "cpack DragNDrop failed (exit ${_CPACK_RESULT})")
	endif()
	message(STATUS "Universal DMG created: ${_PKG_DIR}/${_DMG_NAME}.dmg")
endif()
