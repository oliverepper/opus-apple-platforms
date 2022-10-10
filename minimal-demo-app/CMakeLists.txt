cmake_minimum_required(VERSION 3.24.2)

project(opus-demo VERSION 0.1)

find_package(Opus REQUIRED)

add_executable(opus-demo main.c)

target_link_libraries(opus-demo PRIVATE Opus::opus)
