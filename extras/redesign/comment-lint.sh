#!/usr/bin/env bash
#
# Unterminated-comment / unterminated-string lint for the redesign sources.
#
#   extras/redesign/comment-lint.sh [FILE...]
#
# Without arguments: every tracked or new (not ignored) *.qml, *.cpp, *.hpp under
# modules/gui/qt/redesign/ and modules/gui/qt/tests/. Prints "file:line: message"
# for each problem and exits 1 (0 when clean). linux-tests.sh runs it first, so a
# comment that is never closed fails in a second instead of after a build.
#
# Why: a licence header whose closing */ got lost swallows the rest of a QML file.
# The type is then "unavailable" only where it is used, and a lazily loaded page
# (the Settings modal) is not used by the startup run of qml-smoke.sh. The C++
# compiler would report such a file; QML is only parsed at run time.
#
# A small scanner (awk), not a parser. It knows // and /* */ comments, "..." and
# single-quoted strings (with backslash escapes and line continuations), C++ raw
# strings R"delim(...)delim", digit separators (1'000), and in .qml also template
# strings and /regex/ literals. It reports:
#   - a /* that is never closed (the line of the /*),
#   - a /* that starts a line inside a comment (the usual way a lost closing
#     marker hides: a later doc comment closes the licence header, so nothing is
#     unterminated at the end of the file, but everything between is swallowed),
#   - a "..." or single-quoted string that ends with its line (the line of the quote),
#   - a template or raw string still open at the end of the file.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

case "${1:-}" in
    -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

if [ "$#" -gt 0 ]; then
    files=("$@")
else
    # tracked files plus new ones that are not ignored (a new file of an agent is
    # the likeliest to be broken); NUL-separated so odd names survive. Without a
    # git checkout (an exported tree) every file below the two directories.
    files=()
    if git rev-parse --git-dir >/dev/null 2>&1; then
        listing() { git ls-files -z --cached --others --exclude-standard -- modules/gui/qt/redesign modules/gui/qt/tests; }
    else
        listing() { find modules/gui/qt/redesign modules/gui/qt/tests -type f -print0; }
    fi
    while IFS= read -r -d '' f; do
        case "$f" in *.qml|*.cpp|*.hpp) [ -f "$f" ] && files+=("$f") ;; esac
    done < <(listing)
fi

if [ "${#files[@]}" -eq 0 ]; then
    echo "comment-lint.sh: no source files found (run from a git checkout)" >&2
    exit 1
fi

# (the awk program is in single quotes: an apostrophe is written \047 inside it)
awk '
function err(f, ln, msg) { printf "%s:%d: %s\n", f, ln, msg; bad++ }

function finish(f) {
    if (inblock) err(f, blockline, "unterminated /* comment (opened here, never closed)")
    if (inbt)    err(f, btline, "unterminated template string (opened here, never closed)")
    if (inraw)   err(f, rawline, "unterminated raw string literal (opened here, never closed)")
    if (instr)   err(f, strline, "unterminated string literal at end of file")
    inblock = inbt = inraw = instr = nested = 0
}

function isword(ch) { return ch ~ /^[A-Za-z0-9_]$/ }

FNR == 1 {
    if (cur != "") finish(cur)
    cur = FILENAME
    isqml = (FILENAME ~ /\.qml$/)
}

{
    line = $0
    sub(/\r$/, "", line)
    n = length(line)
    i = 1
    prev = ""            # last significant (non-space, outside comments) character
    while (i <= n) {
        if (inblock) {
            # a comment that opens at the start of a line inside a comment: the
            # first one lost its closing marker (a later */ would close it silently)
            if (i == 1 && line ~ /^[ 	]*\/\*/ && !nested) {
                err(cur, FNR, "/* starts inside the comment opened at line " blockline " (is its closing marker missing?)")
                nested = 1
            }
            j = index(substr(line, i), "*/")
            if (j == 0) { i = n + 1 } else { i += j + 1; inblock = 0; nested = 0; prev = " " }
            continue
        }
        if (inraw) {
            j = index(substr(line, i), rawend)
            if (j == 0) { i = n + 1 } else { i += j - 1 + length(rawend); inraw = 0; prev = ")" }
            continue
        }
        if (instr) {                  # inside a quoted string, possibly continued
            d = substr(line, i, 1)
            if (d == "\\") {
                if (i == n) { i = n + 1; continue }     # backslash-newline: the string goes on
                i += 2
                if (i > n) { err(cur, strline, "unterminated string literal"); instr = 0 }
                continue
            }
            if (d == q) { instr = 0; prev = q }
            i++
            if (instr && i > n) {
                err(cur, strline, "unterminated string literal"); instr = 0
            }
            continue
        }
        if (inbt) {
            d = substr(line, i, 1)
            if (d == "\\") { i += 2; continue }
            if (d == "`") { inbt = 0; prev = "`" }
            i++
            continue
        }
        c = substr(line, i, 1)
        c2 = substr(line, i, 2)
        if (c == " " || c == "\t") { i++; continue }
        if (c2 == "//") break
        if (c2 == "/*") { inblock = 1; blockline = FNR; i += 2; continue }
        if (c == "\"") {
            if (!isqml && i > 1 && substr(line, i - 1, 1) == "R") {
                k = index(substr(line, i + 1), "(")
                if (k > 0) {
                    rawend = ")" substr(line, i + 1, k - 1) "\""
                    inraw = 1; rawline = FNR; i += k + 1; continue
                }
            }
            instr = 1; q = c; strline = FNR; i++
            if (i > n) { err(cur, strline, "unterminated string literal"); instr = 0 }
            continue
        }
        if (c == "\047") {
            if (!isqml && i > 1 && isword(substr(line, i - 1, 1))) {   # C++14 digit separator
                i++; prev = c; continue
            }
            instr = 1; q = c; strline = FNR; i++
            if (i > n) { err(cur, strline, "unterminated string literal"); instr = 0 }
            continue
        }
        if (isqml && c == "`") { inbt = 1; btline = FNR; i++; continue }
        if (isqml && c == "/") {
            # a regex literal if an operand cannot come before it
            if (prev == "" || index("(,=:[!&|?{};+-*%<>~^", prev) > 0) {
                j = i + 1; incls = 0; found = 0
                while (j <= n) {
                    d = substr(line, j, 1)
                    if (d == "\\") { j += 2; continue }
                    if (d == "[") incls = 1
                    else if (d == "]") incls = 0
                    else if (d == "/" && !incls) { found = 1; break }
                    j++
                }
                if (found) { i = j + 1; prev = "/"; continue }
            }
        }
        prev = c
        i++
    }
}

END {
    if (cur != "") finish(cur)
    exit bad ? 1 : 0
}
' "${files[@]}" && rc=0 || rc=$?

if [ "$rc" -ne 0 ]; then
    echo "comment-lint.sh: unterminated comment or string found (see above)" >&2
    exit 1
fi
echo "comment-lint.sh: ${#files[@]} files, no unterminated comment or string"
