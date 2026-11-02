# frozen_string_literal: true

module Bobby
  # Log is the port's console output.
  #
  # Ported from upstream's src/log.rs. Upstream's `log` writes a bare line,
  # `info` prefixes a UTC HH:MM:SS timestamp, `debug` adds the timestamp and
  # then dims the line but only when DEBUG=1 is set, `error` writes
  # "<app> error: <message>" to stderr in red, and `error_and_exit` does the
  # same and leaves with status 255.
  #
  # Upstream's debug_struct uses Rust's "{:#?}" pretty-Debug; the Ruby
  # equivalent of that is #inspect, so debug_struct takes any object.
  module Log
    # Upstream's process::exit(255) in error_and_exit.
    EXIT_ERROR = 255

    # The CARGO_PKG_NAME upstream interpolates into its error prefix.
    APP_NAME = 'bobby'

    ESCAPE_DIM = "\e[2m"
    ESCAPE_RED = "\e[31m"
    ESCAPE_RESET = "\e[0m"

    class << self
      def log(message) = puts(message)

      def info(message) = puts(format_line(message))

      def debug(message) = debug_base(format_line(message))

      def debug_struct(object) = debug_base(object.inspect)

      # Dimmed, and only when DEBUG is exactly "1" — upstream matches on the
      # string, so DEBUG=true or DEBUG=0 stay quiet.
      def debug_base(message)
        if ENV['DEBUG'] == '1'
          puts("#{ESCAPE_DIM}#{message}#{ESCAPE_RESET}")
        end
      end

      def error(message)
        warn("#{ESCAPE_RED}#{APP_NAME} error:#{ESCAPE_RESET} #{message}")
      end

      def error_and_exit(message)
        error(message)
        exit(EXIT_ERROR)
      end

      private

        def format_line(message) = "#{format_timestamp} | #{message}"

        def format_timestamp = Time.now.utc.strftime('%H:%M:%S')
    end
  end
end
