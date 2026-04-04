#!/usr/bin/env sh
# Diva-only repository: there is no C/C++ compiler source here to compile.
# The seed binary bootstrap/diva-linux-amd64 is checked in as the trust root.
#
# To replace the seed you must use tooling OUTSIDE this tree, for example:
#   - Restore legacy C sources from an old git commit on a branch, build with cc,
#     commit the new binary, then delete C sources again; or
#   - When the self-hosted pipeline is complete enough, copy the Diva-built
#     compiler executable (same triple) over bootstrap/diva-linux-amd64.
#
# See bootstrap/README.md.
set -eu
echo "build-bootstrap-seed.sh: this repository has no C sources to build a seed." >&2
echo "Read bootstrap/README.md for how to refresh bootstrap/diva-linux-amd64." >&2
exit 1
