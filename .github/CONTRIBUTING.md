# Contributing

This repository is a Ruby port of [Bobby](https://github.com/hbons/Bobby),
which is written in Rust by [Hylke Bons](https://github.com/hbons). Upstream is
the specification; this port follows it and does not lead it.

Where to take something:

- **A bug in Bobby itself, or a feature request for Bobby** — upstream, at
  <https://github.com/hbons/Bobby/issues>. If the Rust app does it too, it is
  not a porting bug.
- **A bug in the Ruby port** — here. The useful report says what upstream does,
  what this port does instead, and which file you were looking at.
- **A divergence you think is wrong** — `FINDINGS.md` lists the places where
  this port deliberately differs from upstream, each with both sides cited at
  file and line. If the one you found is not there, that is a bug in the
  record as much as in the code.

Before opening a pull request, open an issue and let's agree on the change
first. One-liners and trivial patches are fine without one.

## A note on how this port is written

Upstream's own `.github/CONTRIBUTING.md` asks contributors not to use Large
Language Models, in code or in communication, and says why: Hylke wants to talk
and connect with people, and believes there is much to gain from learning from
each other. That is upstream's rule, on upstream's repository, and it is worth
reading in full before you go there.

This repository cannot adopt it, because it would be false the moment it was
written: the Ruby port in `lib/` and `exe/`, the drive in `test/`, and most of
the prose in `FINDINGS.md` and `PORTING.md` were produced by a language model
working against upstream's source as the spec. Saying so here is the point —
nothing about this port should reach upstream, or be sent to Hylke as a patch,
without a human having read it and being willing to stand behind it as their
own work.

## Running what is here

```shell
nix develop                 # Ruby, GTK 4, libadwaita and the typelibs
xvfb-run ruby exe/bobby     # the app
xvfb-run ruby test/drive_bobby.rb   # the headless drive, and the screenshots
ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
rubocop lib exe spec test   # the custom cops in cops/ are enforced
```

The dev shell prints these on entry. A change to a widget is not finished until
the drive has run it: `ruby -c` and a successful `require` prove nothing about
a user interface.
