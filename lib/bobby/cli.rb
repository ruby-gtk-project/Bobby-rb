# frozen_string_literal: true

#   Bobby, browse SQLite files
#   Copyright (C) 2025  Hylke Bons (hello@planetpeanut.studio)
#   Copyright (C) 2026  ruby-gtk-project, for the Ruby port
#
#   This program is free software: you can redistribute it and/or modify it
#   under the terms of the GNU General Public License v3 or any later version.

require 'pp'

require_relative 'app'

module Bobby
  # Cli handles the four options upstream understands before the GUI starts.
  #
  # Ported from upstream's src/cli.rs. Upstream looks at args[1] only — the
  # first argument after the program name — so a recognised option anywhere
  # else is left alone and treated as a file. ARGV already excludes the
  # program name, so args.first here is upstream's args.get(1).
  #
  # Matching one of the four options prints and exits 0; anything else (a file
  # path, an unknown flag, no arguments at all) falls through and lets the GUI
  # run, which is upstream's `None | Some(_) => return Ok(())`.
  class Cli
    USAGE = 'Usage: bobby [file]...'
    OPTIONS_LINE = '    --help, --version, --deps, --env'
    OPTIONS = %w[--help --version --deps --env].freeze

    def initialize(app) = @app = app

    attr_reader :app

    def parse(args)
      handle(args.first).then do |handled|
        if handled
          exit(0)
        end
      end
    end

    def option_help
      puts(USAGE)
      puts
      puts('Options:')
      puts(OPTIONS_LINE)
      puts
    end

    private

      # True when the argument was one of the options, which is what makes the
      # process exit instead of opening a window.
      def handle(argument)
        OPTIONS.include?(argument).tap do |known|
          if known
            run_option(argument)
          end
        end
      end

      def run_option(argument)
        case argument
        when '--help' then option_help
        when '--version' then puts(App.version_string)
        when '--deps' then puts(App.deps)
        when '--env' then pp(app.to_h)
        end
      end
  end
end
