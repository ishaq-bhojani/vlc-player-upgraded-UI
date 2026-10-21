#!/usr/bin/env bash
#
# Builds the signed update status files of a VLC Reborn release.
#
#   extras/redesign/make-status.sh <build_number> <installer_url> <notes_file> <out_dir> [installer_file]
#
# Writes into <out_dir>:
#   status-win-x64        line 1 "4.0.0.<build_number>", line 2 <installer_url>, then the
#                         notes: the format src/misc/update.c parses
#   status-win-x64.asc    detached, armored signature of that file (what update.c
#                         downloads as <status url>.asc)
#   <installer>.asc       with the 5th argument: detached signature of the installer,
#                         named <basename of installer_file>.asc (update.c downloads
#                         <installer_url>.asc, so upload it next to the installer)
#
# The release workflow uploads these files as assets of the GitHub release, so
# <base>/status-win-x64 resolves through ".../releases/latest/download" (branding.md).
#
# Signing key (environment, never printed, never on a command line):
#   UPDATE_GPG_KEY          armored private key (a GitHub secret); base64 of the
#                           armored text is accepted too
#   UPDATE_GPG_PASSPHRASE   its passphrase (empty or unset: key without passphrase)
# The key is imported into a temporary GNUPGHOME that is deleted on exit; the
# owner's own keyring is never read.
#
# Safety checks: the imported key must be the one embedded in the binary
# (fingerprint of docs/redesign/reborn-update-public.asc, override the file with
# REBORN_UPDATE_PUBKEY), otherwise nothing is signed: a release signed by another
# key would be refused by every installed copy. MAKE_STATUS_ALLOW_ANY_KEY=1 turns
# that check off (tests with a throwaway key only). Every signature is verified
# again before the script succeeds.
#
# The status file must stay byte for byte what was signed: LF line endings, no
# transformation by the upload step.

set -euo pipefail

usage() { sed -n '3,/^$/p' "$0" | sed 's/^# \{0,1\}//'; }
die() { echo "make-status.sh: $*" >&2; exit 1; }

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
esac
[ "$#" -eq 4 ] || [ "$#" -eq 5 ] || { usage >&2; exit 64; }

BUILD="$1"
URL="$2"
NOTES="$3"
OUT="$4"
INSTALLER="${5:-}"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PUBKEY="${REBORN_UPDATE_PUBKEY:-$REPO/docs/redesign/reborn-update-public.asc}"

# update.c reads the version with sscanf "%i": a leading zero would be octal. The
# 4th component also ends up in a Windows version resource (a 16-bit field).
[[ "$BUILD" =~ ^[1-9][0-9]{0,4}$ ]] && [ "$BUILD" -le 65535 ] \
    || die "build_number must be an integer from 1 to 65535 without leading zero (got '$BUILD')"
[[ "$URL" =~ ^https://[^[:space:]]+$ ]] || die "installer_url must be an https URL without spaces"
[ -f "$NOTES" ] || die "notes file not found: $NOTES"
[ -f "$PUBKEY" ] || die "public key not found: $PUBKEY"
[ -z "$INSTALLER" ] || [ -f "$INSTALLER" ] || die "installer file not found: $INSTALLER"
[ -n "${UPDATE_GPG_KEY:-}" ] || die "UPDATE_GPG_KEY is not set (armored private key)"
command -v gpg >/dev/null || die "gpg not found"

# update.c refuses a status file without a description, so check the notes
# (CR removed: the file is signed as written, with LF only).
NOTES_TEXT="$(tr -d '\r' < "$NOTES")"
[[ "$NOTES_TEXT" =~ [^[:space:]] ]] || die "the notes file is empty: update.c rejects a status file without a description"

mkdir -p "$OUT"
STATUS="$OUT/status-win-x64"
{
    printf '4.0.0.%s\n' "$BUILD"
    printf '%s\n' "$URL"
    printf '%s\n' "$NOTES_TEXT"
} > "$STATUS"
# update.c refuses a status file of 64 KiB or more
[ "$(wc -c < "$STATUS")" -lt 65535 ] || die "status file too large for update.c (limit 65534 bytes)"

GH="$(mktemp -d)"
chmod 700 "$GH"
cleanup() {
    gpgconf --homedir "$GH" --kill gpg-agent >/dev/null 2>&1 || true
    rm -rf "$GH"
}
trap cleanup EXIT
export GNUPGHOME="$GH"

# The passphrase travels through a file descriptor, not through argv or the log.
GPG=(gpg --batch --yes --no-tty --pinentry-mode loopback)
pass() { printf '%s' "${UPDATE_GPG_PASSPHRASE:-}"; }

# --- import ----------------------------------------------------------------
KEYTEXT="$UPDATE_GPG_KEY"
if [[ "$KEYTEXT" != *"BEGIN PGP"* ]]; then
    KEYTEXT="$(printf '%s' "$KEYTEXT" | base64 -d 2>/dev/null)" \
        || die "UPDATE_GPG_KEY is neither an armored key nor base64 of one"
fi
printf '%s\n' "$KEYTEXT" | "${GPG[@]}" --passphrase-fd 3 --import 3< <(pass) >/dev/null 2>&1 \
    || die "could not import UPDATE_GPG_KEY"
unset KEYTEXT

mapfile -t SECFPR < <("${GPG[@]}" --list-secret-keys --with-colons 2>/dev/null \
    | awk -F: '$1=="sec"{s=1} s&&$1=="fpr"{print $10; exit}')
[ "${#SECFPR[@]}" -eq 1 ] && [ -n "${SECFPR[0]}" ] || die "UPDATE_GPG_KEY holds no secret key"
FPR="${SECFPR[0]}"
[ "$("${GPG[@]}" --list-secret-keys --with-colons 2>/dev/null | grep -c '^sec:')" -eq 1 ] \
    || die "UPDATE_GPG_KEY must contain exactly one secret key"

if [ "${MAKE_STATUS_ALLOW_ANY_KEY:-}" != "1" ]; then
    EXPECT="$(gpg --homedir "$GH" --batch --no-tty --import-options show-only --import --with-colons "$PUBKEY" 2>/dev/null \
        | awk -F: '$1=="fpr"{print $10; exit}')"
    [ -n "$EXPECT" ] || die "cannot read the fingerprint of $PUBKEY"
    [ "$FPR" = "$EXPECT" ] \
        || die "UPDATE_GPG_KEY is key ${FPR: -16}, but the binary embeds key ${EXPECT: -16}; refusing to sign"
fi

# --- sign ------------------------------------------------------------------
# SHA-256 is what gpg picks for a DSA-2048 key; stated so the result does not
# depend on the gpg version. update.c verifies binary signatures (type 0x00).
sign() {   # sign <file> <signature>
    rm -f "$2"
    "${GPG[@]}" --passphrase-fd 3 --local-user "$FPR!" --digest-algo SHA256 \
        --armor --detach-sign --output "$2" "$1" 3< <(pass) >/dev/null 2>&1 \
        || die "signing $1 failed (wrong passphrase?)"
    "${GPG[@]}" --verify "$2" "$1" >/dev/null 2>&1 || die "self-check of $2 failed"
}

sign "$STATUS" "$STATUS.asc"
if [ -n "$INSTALLER" ]; then
    sign "$INSTALLER" "$OUT/$(basename "$INSTALLER").asc"
fi

echo "make-status.sh: wrote $STATUS (4.0.0.$BUILD), signed by key ${FPR: -16}"
[ -z "$INSTALLER" ] || echo "make-status.sh: wrote $OUT/$(basename "$INSTALLER").asc"
