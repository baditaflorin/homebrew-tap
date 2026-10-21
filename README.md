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
compiler is involved.

### macOS with an old Xcode: use the cask

Homebrew treats a formula without a bottle as a source build, even when it only copies a prebuilt binary, and it
refuses source builds when Xcode is older than its minimum for your macOS version (for example "Your Xcode (16.2) ...
is too outdated" on macOS 26). The same archive is also published as a cask, which skips those checks:

```sh
brew install --cask baditaflorin/tap/fpatch
```

The cask needs Homebrew 7 (`postflight_steps`). The binary is built and sha256-pinned by the maintainer but is not
signed with an Apple developer id; Homebrew marks downloads as quarantined and macOS then kills an unsigned binary on
its first run, so the cask removes that one quarantine flag from the unpacked binary after the download has been
checked against the pinned sha256.

`brew uninstall` also removes dependencies that nothing needs any more, and "nothing" includes formulae from taps
that are not trusted. Look first with `brew autoremove --dry-run`, or set `HOMEBREW_NO_AUTOREMOVE=1`.

## Where the binaries come from

Each tool publishes a GitHub release with one `TOOL_VERSION_OS_ARCH.tar.gz` archive per platform and a
`checksums.txt`. A release is built by the tool's own `scripts/release.sh` on a build machine and verified against
that `checksums.txt` before it is uploaded. The formula here pins the sha256 of each archive, so Homebrew refuses a
download that differs from what was released.

The formulae are generated, not written by hand: `scripts/update-formula.sh` reads a release and its
`checksums.txt` and writes `Formula/NAME.rb` (or, with `--cask`, `Casks/NAME.rb`). After a new release:

```sh
scripts/update-formula.sh --repo baditaflorin/fpatch --tag vX.Y.Z --name fpatch \
  --desc "Exact-match, atomic, all-or-nothing file patcher for agents and scripts" --license MIT
scripts/update-formula.sh --cask --repo baditaflorin/fpatch --tag vX.Y.Z --name fpatch \
  --desc "Exact-match, atomic, all-or-nothing file patcher for agents and scripts"
brew audit --strict --online baditaflorin/tap/fpatch
git add Formula Casks && git commit -m "fpatch vX.Y.Z" && git push
```

`scripts/update-formula.sh --check ...` (add `--cask` for the cask) exits 1 when the committed file differs from what
the release would generate. The script needs bash (3.2 is enough), `gh` and `awk`.

## License

[MIT](LICENSE).
