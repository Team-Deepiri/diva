# The Di toolchain no longer builds from in-tree C sources.
# Install: ./scripts/install.sh (uses bootstrap/diva-linux-amd64 + runtime IR).
# See README.md and docs/selfhost-bootstrap.md.
cmake_minimum_required(VERSION 3.20)
project(di NONE)
message(FATAL_ERROR
  "In-tree CMake build removed. Use scripts/install.sh (bootstrap seed + LLVM runtime). "
  "See README.md.")
