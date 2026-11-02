# frozen_string_literal: true

#   Bobby, browse SQLite files
#   Copyright (C) 2025  Hylke Bons (hello@planetpeanut.studio)
#   Copyright (C) 2026  ruby-gtk-project, for the Ruby port
#
#   This program is free software: you can redistribute it and/or modify it
#   under the terms of the GNU General Public License v3 or any later version.

require_relative 'app'
require_relative 'cli'
require_relative 'log'

module Bobby
  # Preflight is everything upstream's main() does before gui_run(): the
  # version line on DEBUG, the refusal to run as root, and the CLI options
  # when there is a terminal to print them to.
  #
  # Ported from the body of upstream's src/main.rs. It is a file of its own
  # rather than part of Application because none of it needs a display and all
  # of it has to happen before one is asked for. Upstream gets that ordering
  # for free: gtk_init only runs inside app.run(), so `bobby --version` prints
  # and leaves on a headless machine. The Ruby gtk4 gem calls gtk_init while
  # it is being required, so the only way to keep the same behaviour is to
  # reach the CLI without having loaded the gem — which is why this file
  # requires app, cli and log and nothing else, and why exe/bobby runs it
  # before it requires the rest of the app.
  #
  # Application#start still calls it, so a caller that holds an Application
  # gets upstream's main() in one piece.
  module Preflight
    ROOT_REFUSAL = 'Cannot run as root'

    class << self
      def run(argv, app_info: App.new)
        Log.debug_base(App.version_string)

        if App.runs_as_root?
          Log.error_and_exit(ROOT_REFUSAL)
        end

        if App.runs_in_terminal?
          Cli.new(app_info).parse(argv)
        end
      end
    end
  end
end
