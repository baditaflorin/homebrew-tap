# homebrew-tap

[Homebrew](https://brew.sh) formulae for [baditaflorin](https://github.com/baditaflorin)'s public command-line tools.

| Formula | What it is |
|---|---|
| [`fpatch`](https://github.com/baditaflorin/fpatch) | Exact-match, atomic, all-or-nothing file patcher for agents and scripts |

## Install

```sh
brew install baditaflorin/tap/fpatch
```

Use the full name `baditaflorin/tap/fpatch`. Since Homebrew 6, a tap that is not Homebrew's own must be trusted before
Homebrew loads it, and installing by the fully qualified name trusts only that one formula. To install by the short
name instead, trust the formula first:

```sh
brew tap baditaflorin/tap
brew trust --formula baditaflorin/tap/fpatch
brew install fpatch
```

See Homebrew's [Tap Trust](https://docs.brew.sh/Tap-Trust) page for what trust means. Update and remove as usual:
`brew upgrade fpatch`, `brew uninstall fpatch`.

Platforms: macOS and Linux, on arm64 and amd64. The formulae install a prebuilt, statically linked binary, so no
compiler and no Xcode build step is involved.

## Where the binaries come from

Each tool publishes a GitHub release with one `TOOL_VERSION_OS_ARCH.tar.gz` archive per platform and a
`checksums.txt`. A release is built by the tool's own `scripts/release.sh` on a build machine and verified against
that `checksums.txt` before it is uploaded. The formula here pins the sha256 of each archive, so Homebrew refuses a
download that differs from what was released.

The formulae are generated, not written by hand: `scripts/update-formula.sh` reads a release and its
`checksums.txt` and writes `Formula/NAME.rb`. After a new release:

```sh
scripts/update-formula.sh --repo baditaflorin/fpatch --tag vX.Y.Z --name fpatch \
  --desc "Exact-match, atomic, all-or-nothing file patcher for agents and scripts" --license MIT
brew audit --strict --online baditaflorin/tap/fpatch
git add Formula && git commit -m "fpatch vX.Y.Z" && git push
```

`scripts/update-formula.sh --check ...` exits 1 when the committed formula differs from what the release would
generate. The script needs bash (3.2 is enough), `gh` and `awk`.

## License

[MIT](LICENSE).
