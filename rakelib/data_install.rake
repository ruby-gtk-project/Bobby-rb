# frozen_string_literal: true

#   Bobby, browse SQLite files
#   Copyright (C) 2025  Hylke Bons (hello@planetpeanut.studio)
#   Copyright (C) 2026  ruby-gtk-project, for the Ruby port
#
#   This program is free software: you can redistribute it and/or modify it
#   under the terms of the GNU General Public License v3 or any later version.

# The port's answer to upstream's data/meson.build and data/icons/meson.build.
#
# Upstream installs five files under a prefix: the desktop entry into
# share/applications, the AppStream metainfo into share/metainfo, the GSettings
# schema into share/glib-2.0/schemas, and the two icons into
# share/icons/hicolor/{scalable,symbolic}/apps. Installing a gem does none of
# that — `spec.files` globs data/**/* into the gem and leaves it inside the
# gem's own directory — so without this task Bobby does not appear in the app
# grid and a .db file has no Open With -> Bobby.
#
#   rake data:install                 # into ~/.local
#   PREFIX=/usr/local rake data:install
#   rake data:uninstall
#
# The schema is compiled after the copy, as meson's gnome.post_install does.

require "fileutils"

module BobbyDataInstall
  APPLICATION_ID = "studio.planetpeanut.Bobby"

  SOURCE = File.expand_path("../data", __dir__)

  SCALABLE_DIR = "hicolor/scalable/apps"
  SYMBOLIC_DIR = "hicolor/symbolic/apps"

  class << self
    def prefix = ENV.fetch("PREFIX", File.join(Dir.home, ".local"))

    def share = File.join(prefix, "share")

    # Every file this task owns, as source => installed path.
    def files
      {
        File.join(SOURCE, "#{APPLICATION_ID}.desktop") =>
          File.join(share, "applications", "#{APPLICATION_ID}.desktop"),
        File.join(SOURCE, "#{APPLICATION_ID}.metainfo.xml") =>
          File.join(share, "metainfo", "#{APPLICATION_ID}.metainfo.xml"),
        File.join(SOURCE, "#{APPLICATION_ID}.gschema.xml") =>
          File.join(
            share,
            "glib-2.0",
            "schemas",
            "#{APPLICATION_ID}.gschema.xml",
          ),
        File.join(
          SOURCE,
          "icons",
          SCALABLE_DIR,
          "#{APPLICATION_ID}.svg",
        ) =>
          File.join(
            share,
            "icons",
            SCALABLE_DIR,
            "#{APPLICATION_ID}.svg",
          ),
        File.join(
          SOURCE,
          "icons",
          SYMBOLIC_DIR,
          "#{APPLICATION_ID}-symbolic.svg",
        ) =>
          File.join(
            share,
            "icons",
            SYMBOLIC_DIR,
            "#{APPLICATION_ID}-symbolic.svg",
          ),
      }
    end

    def schema_dir = File.join(share, "glib-2.0", "schemas")

    def install
      files.each do |source, target|
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.install(source, target, mode: 0o644)
        puts "installed #{target}"
      end

      compile_schemas
      update_caches
    end

    def uninstall
      files.each_value do |target|
        if File.exist?(target)
          FileUtils.rm(target)
          puts "removed #{target}"
        end
      end

      compile_schemas
      update_caches
    end

    # meson's gnome.post_install does these three; a gem install has no
    # post-install hook that is allowed to touch the user's data directory, so
    # they are run here, and skipped when the tool is not on PATH rather than
    # failing the task.
    def compile_schemas
      run("glib-compile-schemas", schema_dir)
    end

    def update_caches
      run(
        "gtk4-update-icon-cache",
        "-q",
        "-t",
        "-f",
        File.join(share, "icons", "hicolor"),
      )
      run("update-desktop-database", "-q", File.join(share, "applications"))
    end

    def run(command, *arguments)
      if which(command).nil?
        puts "skipped #{command}: not on PATH"
      else
        system(command, *arguments)
        puts "ran #{command}"
      end
    end

    def which(command)
      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR)
        .map { |directory| File.join(directory, command) }
        .find { |candidate| File.executable?(candidate) && !File.directory?(candidate) }
    end
  end
end

namespace :data do
  desc "Install the desktop entry, metainfo, GSettings schema and icons under PREFIX (default ~/.local)"
  task :install do
    BobbyDataInstall.install
  end

  desc "Remove what data:install installed from PREFIX (default ~/.local)"
  task :uninstall do
    BobbyDataInstall.uninstall
  end
end
