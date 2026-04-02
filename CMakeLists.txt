cmake_minimum_required(VERSION 3.20)

project(di LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

find_package(LLVM CONFIG QUIET)

if(LLVM_FOUND)
  message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION}")
  message(STATUS "Using LLVMConfig.cmake in: ${LLVM_DIR}")
  include_directories(${LLVM_INCLUDE_DIRS})
  add_definitions(${LLVM_DEFINITIONS})
endif()

include_directories(include)

set(DI_SOURCES
  src/main.c
  src/driver.c
  src/diag.c
  src/token.c
  src/lexer.c
  src/ast.c
  src/parser.c
  src/sema.c
  src/codegen_llvm.c
)

add_executable(di ${DI_SOURCES})

if(LLVM_FOUND)
  if(TARGET LLVM)
    target_link_libraries(di PRIVATE LLVM)
  endif()
endif()
