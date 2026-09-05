#!/bin/sh

set -eu

# Prints JEMALLOC_CONFIGURE_OPTS for deps/Makefile (no Makefile edits).
# Page size matches Debian jemalloc: x86 4KiB, others 64KiB; hugepage 2MiB.
gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"
dpkgArch="$(dpkg --print-architecture)"

case "${dpkgArch##*-}" in
  amd64|i386|x32) lgPage=12 ;;
  *) lgPage=16 ;;
esac

printf '%s\n' "--build=${gnuArch} --with-lg-page=${lgPage} --with-lg-hugepage=21"
