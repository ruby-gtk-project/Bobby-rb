# Changelog

[![SemVer 2.0.0][📌semver-img]][📌semver] [![Keep-A-Changelog 1.0.0][📗keep-changelog-img]][📗keep-changelog]

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog][📗keep-changelog],
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html),
and [yes][📌major-versions-not-sacred], platform and engine support are part of the [public API][📌semver-breaking].
Please file a bug if you notice a violation of semantic versioning.

[📌semver]: https://semver.org/spec/v2.0.0.html
[📌semver-img]: https://img.shields.io/badge/semver-2.0.0-FFDD67.svg?style=flat
[📌semver-breaking]: https://github.com/semver/semver/issues/716#issuecomment-869336139
[📌major-versions-not-sacred]: https://tom.preston-werner.com/2022/05/23/major-version-numbers-are-not-sacred.html
[📗keep-changelog]: https://keepachangelog.com/en/1.0.0/
[📗keep-changelog-img]: https://img.shields.io/badge/keep--a--changelog-1.0.0-FFDD67.svg?style=flat

## [Unreleased]

### Added

- `Sqlite::Cache` is a lazy `Gio::ListModel`, ported from upstream's `DatabaseCacheModel`: 256-row pages fetched on demand around the index the view asks for, a ±256 guard radius, and one cached row count. A table of any size opens without being read whole.
- `Sqlite::Row.page` and `Sqlite::Database#page`, a paged query counted in list-model indices rather than in rowids.
- `Widgets::Content#detach`, which takes the model off the `Gtk::ColumnView` before the content is let go.

### Changed

### Deprecated

### Removed

### Fixed

- Opening a large table no longer reads every row into memory before the window appears.
- A `Gtk::ColumnView` collected by Ruby's garbage collector no longer aborts the process: GTK asked the Ruby-implemented model for items from inside the view's dispose, which ran Ruby inside a GC phase.

### Security

[Unreleased]: https://gitlab.com/ruby-gtk-project/Bobby-rb/-/compare/HEAD
