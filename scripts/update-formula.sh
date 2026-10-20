#!/usr/bin/env bash
# Generate (or refresh) the Homebrew formula of one tool from its GitHub release.
#
#   scripts/update-formula.sh --repo OWNER/REPO --tag vX.Y.Z --name NAME [options]
#
#   --repo OWNER/REPO    the repository whose release holds NAME_VERSION_OS_ARCH.tar.gz archives and checksums.txt
#   --tag vX.Y.Z         the release to describe
#   --name NAME          formula name and binary name (the archive holds a file called NAME)
#   --desc TEXT          one-line description (default: the repository's description)
#   --homepage URL       default https://github.com/OWNER/REPO
#   --license SPDX       for example MIT; omitted from the formula when not given
#   --private            the repository is private: the formula downloads through the GitHub API asset URL
#                        and sends HOMEBREW_GITHUB_API_TOKEN (Homebrew only expands it at download time)
#   --out FILE           where to write (default Formula/NAME.rb)
#   --check              write nothing; exit 1 when FILE differs from what would be generated
#
# It reads the release with gh (an authenticated gh is needed for a private repository, and fine for a
# public one), takes every sha256 from the release's own checksums.txt, and refuses when an archive for one
# of the four platforms (macOS and Linux, arm64 and amd64) is missing. Works with bash 3.2 and needs gh, awk.
set -euo pipefail

repo=
tag=
name=
desc=
homepage=
license=
private=0
out=
check=0
tmp=

cleanup() { [ -z "$tmp" ] || rm -rf "$tmp"; }
trap cleanup EXIT
die() { printf 'update-formula: %s\n' "$*" >&2; exit 1; }
usage_error() { printf 'update-formula: %s\nusage: scripts/update-formula.sh --repo OWNER/REPO --tag vX.Y.Z --name NAME [--private] [--desc TEXT] [--license SPDX] [--check]\n' "$*" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case $1 in
    --repo)     [ $# -ge 2 ] || usage_error "--repo needs a value"; repo=$2; shift 2 ;;
    --tag)      [ $# -ge 2 ] || usage_error "--tag needs a value"; tag=$2; shift 2 ;;
    --name)     [ $# -ge 2 ] || usage_error "--name needs a value"; name=$2; shift 2 ;;
    --desc)     [ $# -ge 2 ] || usage_error "--desc needs a value"; desc=$2; shift 2 ;;
    --homepage) [ $# -ge 2 ] || usage_error "--homepage needs a value"; homepage=$2; shift 2 ;;
    --license)  [ $# -ge 2 ] || usage_error "--license needs a value"; license=$2; shift 2 ;;
    --out)      [ $# -ge 2 ] || usage_error "--out needs a value"; out=$2; shift 2 ;;
    --private)  private=1; shift ;;
    --check)    check=1; shift ;;
    -h|--help)  awk 'NR == 1 { next } /^set -euo/ { exit } { sub(/^# ?/, ""); print }' "$0"; exit 0 ;;
    *)          usage_error "unknown argument: $1" ;;
  esac
done

repo_re='^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'
tag_re='^v[0-9]+\.[0-9]+\.[0-9]+$'
name_re='^[a-z][a-z0-9]*(-[a-z0-9]+)*$'
license_re='^[A-Za-z0-9.+-]+$'
[ -n "$repo" ] && [[ $repo =~ $repo_re ]] || usage_error "--repo must look like OWNER/REPO"
[ -n "$tag" ] && [[ $tag =~ $tag_re ]] || usage_error "--tag must look like vX.Y.Z"
[ -n "$name" ] && [[ $name =~ $name_re ]] || usage_error "--name must be a lower-case formula name such as my-tool"
[ -z "$license" ] || [[ $license =~ $license_re ]] || usage_error "--license must be an SPDX id such as MIT"
command -v gh >/dev/null 2>&1 || die "gh (the GitHub CLI) is needed"
command -v awk >/dev/null 2>&1 || die "awk is needed"

ver=${tag#v}
[ -n "$homepage" ] || homepage=https://github.com/$repo
[ -n "$out" ] || out=Formula/$name.rb
if [ -z "$desc" ]; then
  desc=$(gh repo view "$repo" --json description --jq '.description // ""' 2>/dev/null) || desc=
  [ -n "$desc" ] || die "the repository has no description: pass --desc"
fi
case $desc in *\"*|*\\*|*'#{'*) die "--desc may not contain a double quote, a backslash or #{" ;; esac

tmp=$(mktemp -d "${TMPDIR:-/tmp}/update-formula.XXXXXX")
gh api "repos/$repo/releases/tags/$tag" --jq '.assets[] | "\(.id)\t\(.name)"' >"$tmp/assets" \
  || die "cannot read release $tag of $repo (no such release, or gh has no access)"
gh release download "$tag" --repo "$repo" --pattern checksums.txt --dir "$tmp" \
  || die "release $tag of $repo has no checksums.txt"

# lookup FILE KEY-FIELD VALUE-FIELD KEY: prints the VALUE-FIELD of the single row whose KEY-FIELD equals KEY
lookup() {
  awk -v kf="$2" -v vf="$3" -v k="$4" '{ f = $kf; sub(/^\*/, "", f); if (f == k) { print $vf; n++ } } END { exit n == 1 ? 0 : 1 }' "$1"
}

sha_re='^[0-9a-f]{64}$'
ids=
shas=
for p in darwin_arm64 darwin_amd64 linux_arm64 linux_amd64; do
  archive=${name}_${ver}_${p}.tar.gz
  sha=$(lookup "$tmp/checksums.txt" 2 1 "$archive") || die "checksums.txt has no (or a duplicate) line for $archive"
  [[ $sha =~ $sha_re ]] || die "checksums.txt has a malformed checksum for $archive"
  id=$(lookup "$tmp/assets" 2 1 "$archive") || die "release $tag of $repo has no asset named $archive"
  ids="$ids $p=$id"
  shas="$shas $p=$sha"
done
get() { local kv; for kv in $2; do case $kv in "$1="*) printf '%s' "${kv#*=}"; return 0 ;; esac; done; return 1; }

class=$(printf '%s' "$name" | awk -F- '{ for (i = 1; i <= NF; i++) printf "%s%s", toupper(substr($i, 1, 1)), substr($i, 2) }')

# stanza OS_BLOCK ARCH_BLOCK PLATFORM
stanza() {
  local p=$3 archive id sha
  archive=${name}_${ver}_${p}.tar.gz
  sha=$(get "$p" "$shas")
  id=$(get "$p" "$ids")
  printf '    %s do\n' "$2"
  if [ "$private" = 1 ]; then
    printf '      url "https://api.github.com/repos/%s/releases/assets/%s",\n' "$repo" "$id"
    printf '          headers: ["Accept: application/octet-stream",\n'
    printf '                    "Authorization: Bearer #{ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", "")}"]\n'
  else
    printf '      url "https://github.com/%s/releases/download/%s/%s"\n' "$repo" "$tag" "$archive"
  fi
  printf '      sha256 "%s"\n' "$sha"
  printf '    end\n'
}

render() {
  printf '# Generated by scripts/update-formula.sh from %s %s. Do not edit by hand: rerun the script.\n' "$repo" "$tag"
  printf 'class %s < Formula\n' "$class"
  printf '  desc "%s"\n' "$desc"
  printf '  homepage "%s"\n' "$homepage"
  printf '  version "%s"\n' "$ver"
  [ -z "$license" ] || printf '  license "%s"\n' "$license"
  printf '\n'
  printf '  on_macos do\n'
  stanza on_macos on_arm darwin_arm64
  stanza on_macos on_intel darwin_amd64
  printf '  end\n\n'
  printf '  on_linux do\n'
  stanza on_linux on_arm linux_arm64
  stanza on_linux on_intel linux_amd64
  printf '  end\n\n'
  printf '  def install\n'
  printf '    bin.install "%s"\n' "$name"
  printf '  end\n\n'
  printf '  test do\n'
  printf '    assert_equal version.to_s, shell_output("#{bin}/%s --version").strip\n' "$name"
  printf '  end\n'
  printf 'end\n'
}

render >"$tmp/formula.rb"
if [ "$check" = 1 ]; then
  if [ -f "$out" ] && cmp -s "$tmp/formula.rb" "$out"; then
    printf '%s is up to date with %s %s\n' "$out" "$repo" "$tag"
    exit 0
  fi
  printf '%s differs from what %s %s would generate\n' "$out" "$repo" "$tag" >&2
  exit 1
fi
mkdir -p "$(dirname "$out")"
mv "$tmp/formula.rb" "$out"
printf 'wrote %s (%s %s%s)\n' "$out" "$repo" "$tag" "$([ "$private" = 1 ] && printf ', private release via the API asset URL')"
