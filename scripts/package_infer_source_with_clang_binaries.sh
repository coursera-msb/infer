#!/bin/bash

# Copyright (c) 2013 - present Facebook, Inc.
# All rights reserved.
#
# This source code is licensed under the BSD style license found in the
# LICENSE file in the root directory of this source tree. An additional grant
# of patent rights can be found in the PATENTS file in the same directory.

set -x
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
ROOT_INFER_DIR="$SCRIPT_DIR"/..
CLANG_PLUGIN_DIR="$ROOT_INFER_DIR"/facebook-clang-plugins
PLATFORM=`uname`
INFER_SOURCE="$ROOT_INFER_DIR"/infer-source

# Build infer and facebook-clang-plugins
cd "$ROOT_INFER_DIR"
# This assumes the current commit is the one with the release bump
./build-infer.sh

# Get a copy of the github repo
git clone https://github.com/facebook/infer.git "$INFER_SOURCE"
pushd "$INFER_SOURCE"
# Name of the release package
VERSION=`git describe --abbrev=0 --tags`
if [ "$PLATFORM" == 'Darwin' ]; then
    RELEASE_NAME=infer-osx-"$VERSION"
else
    RELEASE_NAME=infer-linux64-"$VERSION"
fi
RELEASE_TARBALL="$RELEASE_NAME".tar.xz
PKG_DIR="$ROOT_INFER_DIR"/"$RELEASE_NAME"
PKG_PLUGIN_DIR="$PKG_DIR"/facebook-clang-plugins

git checkout "$VERSION"
git submodule update --init
popd

# Copy infer source
mkdir -p "$PKG_DIR"
rsync -a \
  --exclude="**/.git" \
  --exclude="**/.gitmodules" \
  --exclude="**/.gitignore" \
  --exclude="facebook-clang-plugins/clang/src/clang-*.tar.*" \
  "$INFER_SOURCE"/ "$PKG_DIR"/
touch "$PKG_DIR"/.release
rsync -a "$ROOT_INFER_DIR"/configure "$PKG_DIR"/configure

mkdir -pv "$PKG_PLUGIN_DIR"/clang/{bin,lib,include}
mkdir -pv "$PKG_PLUGIN_DIR"/libtooling/build
mkdir -pv "$PKG_PLUGIN_DIR"/clang-ocaml/build
rsync -a "$CLANG_PLUGIN_DIR"/{CONTRIBUTING.md,LICENSE,LLVM-LICENSE,PATENTS,README.md} "$PKG_PLUGIN_DIR"
rsync -a "$CLANG_PLUGIN_DIR"/clang/bin/clang* "$PKG_PLUGIN_DIR"/clang/bin/
rsync -a --exclude '*.a' "$CLANG_PLUGIN_DIR"/clang/lib/ "$PKG_PLUGIN_DIR"/clang/lib/
rsync -a "$CLANG_PLUGIN_DIR"/clang/include/ "$PKG_PLUGIN_DIR"/clang/include/
rsync -a "$CLANG_PLUGIN_DIR"/libtooling/build/ "$PKG_PLUGIN_DIR"/libtooling/build/
rsync -a "$CLANG_PLUGIN_DIR"/clang-ocaml/build/ "$PKG_PLUGIN_DIR"/clang-ocaml/build/

# no clang source in release versions, so remove the corresponding
# checksum check
grep -v -e '\bsrc/clang-.*\.tar\.*' \
  < "$CLANG_PLUGIN_DIR"/clang/installed.version \
  > "$PKG_PLUGIN_DIR"/clang/installed.version

FBONLY=FB-ONLY
if grep -Ir --exclude="$SCRIPT_NAME" "$FBONLY" "$PKG_DIR"; then
    echo "Found files marked $FBONLY"
    exit 1
fi

cd "$ROOT_INFER_DIR" && tar cJf "$RELEASE_TARBALL" "$RELEASE_NAME"

# Cleanup.
rm -rf "$PKG_DIR" "$INFER_SOURCE"
