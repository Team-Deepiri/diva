cmake_minimum_required(VERSION 3.20)

project(di NONE)

message(FATAL_ERROR
  "The Di reference compiler is not built from C sources in this tree.\n"
  "  Install the toolchain: ./scripts/install.sh\n"
  "  (installs the bootstrap compiler from bootstrap/di-linux-amd64, LLVM IR runtime, and stdlib.)\n"
  "  Requires: cc, and optionally clang (to compile runtime/runtime.ll to ~/.local/share/di/runtime/runtime.o)."
)
