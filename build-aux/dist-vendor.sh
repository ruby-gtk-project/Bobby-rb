#!/bin/sh

#   Bobby, browse SQLite files
#   Copyright (C) 2025  Hylke Bons (hello@planetpeanut.studio)
#   Copyright (C) 2026  ruby-gtk-project, for the Ruby port
#
#   This program is free software: you can redistribute it and/or modify it
#   under the terms of the GNU General Public License v3 or any later version.

# Ported from upstream's build-aux/dist-vendor.sh. Upstream's script runs
# `cargo vendor` against $1 (SOURCE_ROOT) and moves the result into $2
# (DIST), so a release tarball built from DIST carries every crate it needs
# and `cargo build --offline` can resolve them without network access during
# the Flatpak build. Bundler's equivalent of `cargo vendor` is
# `bundle package`: it downloads the .gem files a Gemfile resolves to into
# vendor/cache, and a Gemfile.lock alongside them pins exactly which ones.
#
# This script resolves against Gemfile.flatpak, not the root Gemfile — the
# root Gemfile also resolves the lint/test/release tooling in
# gemfiles/modular/*.gemfile, none of which the shipped app needs vendored.
#
# Usage, same signature as upstream's:
#
#   build-aux/dist-vendor.sh <source root> <dist dir>
#
# What lands in DIST: vendor/cache/*.gem, Gemfile.flatpak and the
# Gemfile.flatpak.lock that `bundle package` writes next to it. A production
# Flatpak build points studio.planetpeanut.Bobby.yml's `bobby` module at a
# release tarball built from DIST and runs
# `BUNDLE_GEMFILE=Gemfile.flatpak bundle install --local`, which resolves
# entirely out of the vendored cache.

set -e

SOURCE_ROOT="$1"
DIST="$2"

if [ -z "$SOURCE_ROOT" ] || [ -z "$DIST" ]; then
  echo "usage: $0 <source root> <dist dir>" >&2
  exit 1
fi

cd "$SOURCE_ROOT"

BUNDLE_GEMFILE="$SOURCE_ROOT/Gemfile.flatpak" bundle config set --local without 'development test'
BUNDLE_GEMFILE="$SOURCE_ROOT/Gemfile.flatpak" bundle package --all-platforms

mkdir -p "$DIST"
cp Gemfile.flatpak "$DIST/Gemfile.flatpak"
cp Gemfile.flatpak.lock "$DIST/Gemfile.flatpak.lock"
mv vendor "$DIST/vendor"
