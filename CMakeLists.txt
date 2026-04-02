cmake_minimum_required(VERSION 3.20)

project(di LANGUAGES NONE)

message(STATUS "The Di reference compiler is not built from C sources in this tree.")
message(STATUS "Use ./scripts/install.sh (bootstrap/di-linux-amd64) or build the Di driver in compiler/.")
message(STATUS "Maintainers: see scripts/rebuild-bootstrap.sh to refresh bootstrap/di-linux-amd64 from a C toolchain checkout.")
