# frozen_string_literal: true

#   Bobby, browse SQLite files
#   Copyright (C) 2025  Hylke Bons (hello@planetpeanut.studio)
#   Copyright (C) 2026  ruby-gtk-project, for the Ruby port
#
#   This program is free software: you can redistribute it and/or modify it
#   under the terms of the GNU General Public License v3 or any later version.

require_relative "bobby/app"
require_relative "bobby/application"
require_relative "bobby/cli"
require_relative "bobby/icons"
require_relative "bobby/log"
require_relative "bobby/preflight"
require_relative "bobby/settings"
require_relative "bobby/util"
require_relative "bobby/window"
require_relative "bobby/dialogs/about"
require_relative "bobby/dialogs/file"
require_relative "bobby/dialogs/preferences"
require_relative "bobby/dialogs/shortcuts"
require_relative "bobby/sqlite/affinity"
require_relative "bobby/sqlite/cache"
require_relative "bobby/sqlite/column"
require_relative "bobby/sqlite/database"
require_relative "bobby/sqlite/row"
require_relative "bobby/sqlite/table"
require_relative "bobby/widgets/button"
require_relative "bobby/widgets/content"
require_relative "bobby/widgets/drop_target"
require_relative "bobby/widgets/item"
require_relative "bobby/widgets/menu"
require_relative "bobby/widgets/switcher"
