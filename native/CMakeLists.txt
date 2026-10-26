cmake_minimum_required(VERSION 3.21)
project(omarky_native LANGUAGES CXX)

# The one native piece of Omarky: a QSyntaxHighlighter for the editor's
# QQuickTextDocument (docs/decisions/0014). Built by Omarky::Native into an
# app's build/qml, which goes on QML_IMPORT_PATH.

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick)
set(QT_NO_PRIVATE_MODULE_WARNING ON)
# Private: only for the undo flag in markdownhighlighter.cpp (decision 0002).
find_package(Qt6 REQUIRED COMPONENTS GuiPrivate)
find_package(KF6Sonnet QUIET)

qt_standard_project_setup(REQUIRES 6.5)
set(QT_QML_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml)

qt_add_qml_module(omarkynative
  URI Omarky.Native
  VERSION 1.0
  PLUGIN_TARGET omarkynative
  SOURCES
    markdownhighlighter.h markdownhighlighter.cpp
)

target_link_libraries(omarkynative PRIVATE Qt6::Core Qt6::Gui Qt6::GuiPrivate Qt6::Qml Qt6::Quick)

if(KF6Sonnet_FOUND)
  target_link_libraries(omarkynative PRIVATE KF6::SonnetCore)
  target_compile_definitions(omarkynative PRIVATE OMARKY_SONNET=1)
  message(STATUS "Omarky: spell checking with Sonnet")
else()
  message(STATUS "Omarky: Sonnet not found, no spell checking")
endif()
