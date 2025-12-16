cmake_minimum_required(VERSION 2.8)

option(RECASTNAVIGATION_STATIC "Build static libraries" ON)

set(CXX_FLAGS
    -fPIC
)

string(REPLACE ";" " " CMAKE_CXX_FLAGS "${CXX_FLAGS}")
set(CMAKE_CXX_COMPILER "g++")

file(GLOB SOURCES Source/*.cpp)

if (RECASTNAVIGATION_STATIC)
    add_library(DetourTileCache STATIC ${SOURCES})
else ()
    add_library(DetourTileCache SHARED ${SOURCES})
endif ()

add_library(RecastNavigation::DetourTileCache ALIAS DetourTileCache)

set(DetourTileCache_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/Include" "${CMAKE_CURRENT_SOURCE_DIR}/../Detour/Include")

target_include_directories(DetourTileCache PUBLIC
    "$<BUILD_INTERFACE:${DetourTileCache_INCLUDE_DIR}>"
)

target_link_libraries(DetourTileCache
    Detour
)

set_target_properties(DetourTileCache PROPERTIES
        SOVERSION ${SOVERSION}
        VERSION ${VERSION}
        )


install(TARGETS DetourTileCache
        ARCHIVE DESTINATION lib
        LIBRARY DESTINATION lib
        COMPONENT library
        )

file(GLOB INCLUDES Include/*.h)
install(FILES ${INCLUDES} DESTINATION include)
