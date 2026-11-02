# Release Steps

Ported from upstream's `info/release-steps.md`. Upstream releases a meson and
cargo build to Flathub; this port releases a Ruby gem, so steps 1, 3, 4 and 6
are the gem equivalents of what upstream does there, and the rest is upstream's
list unchanged.

## 0. Slow down and enjoy 🌱

* Reflect on the improvements made
* When ready, follow the next steps in order


## 1. Bump version number

* Edit `./lib/bobby/rb/version.rb`

```shell
git add ./lib/bobby/rb/version.rb ./CHANGELOG.md
git status
git commit -m "meta: Bump version to v<VERSION>"
git push
```


## 2. Update release notes

* Edit `./data/studio.planetpeanut.Bobby.metainfo.xml`

```shell
git add ./data/*.metainfo.xml
git status
git commit -m "meta: Update release notes for v<VERSION>"
git push
```


## 3. Build the gem

```shell
rake build
ls ./pkg
```

Upstream builds a `meson dist` tarball here. The gem is the port's tarball:
`spec.files` in `bobby-rb.gemspec` globs `lib/`, `exe/` and `data/**/*` into
it, so the desktop entry, the metainfo, the schema and the icons travel with
the code. They are installed by `rake data:install`, which is this port's
`data/meson.build`.


## 4. Check what the gem will install

```shell
gem contents --spec-file ./bobby-rb.gemspec
shasum -a 256 ./pkg/*.gem
PREFIX=/tmp/bobby-release rake data:install
```

The last line is a dry run of what a user gets: the desktop entry in
`share/applications`, the metainfo in `share/metainfo`, the compiled schema in
`share/glib-2.0/schemas` and the two icons in `share/icons/hicolor`.


## 5. Tag release

```shell
git tag v<VERSION> HEAD
git push --tags
```

* Create a **new release** on [GitHub](https://github.com)
  * Upload the built `.gem`
  * Select the newly pushed tag name and use `Bobby-rb v<VERSION>` as the title


## 6. Publish to RubyGems

```shell
gem push ./pkg/bobby-rb-<VERSION>.gem
```

Upstream publishes to Flathub at this step instead, by opening a PR against
`https://github.com/flathub/studio.planetpeanut.Bobby`. This port has no
Flatpak manifest yet — see `FINDINGS.md` — so there is nothing to bump there.


## 7. Celebrate! 🥳
