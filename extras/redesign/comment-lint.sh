#!/usr/bin/env bash
#
# Unterminated-comment / unterminated-string lint for the redesign sources.
#
#   extras/redesign/comment-lint.sh [FILE...]
#   extras/redesign/comment-lint.sh --self-test
#
# Without arguments: every tracked or new (not ignored) *.qml, *.cpp, *.hpp under
# modules/gui/qt/redesign/ and modules/gui/qt/tests/. Prints "file:line: message"
# for each problem and exits 1 (0 when clean). linux-tests.sh runs the self-test
# and then the lint first, so a comment that is never closed fails in a second
# instead of after a build (it exits 1 before Docker and meson are started).
#
# Why: a licence header whose closing */ got lost swallows the rest of a QML file.
# The type is then "unavailable" only where it is used, and a lazily loaded page
# (the Settings modal) is not used by the startup run of qml-smoke.sh. The C++
# compiler would report such a file; QML is only parsed at run time.
#
# A small scanner (awk), not a parser. It knows // and /* */ comments, "..." and
# single-quoted strings (with backslash escapes and line continuations), C++ raw
# strings R"delim(...)delim", C++ digit separators (1'000, only inside a numeric
# token) and character prefixes (L'x', u8'x'), and in .qml also template strings
# and /regex/ literals (a "/" starts one after an operator, an opening bracket or
# one of return typeof case in of void delete throw yield await new instanceof
# else do; "prev" is carried over line ends, so a continuation line that starts
# with "/ 2" is a division). In C++ the text of a preprocessor directive line
# (# at the start of the line, with its backslash continuations) is not scanned for
# quotes (#error don't ...); a /* opened on such a line still counts. It reports:
#   - a /* that is never closed (the line of the /*),
#   - a /* that starts a line inside a comment, which is how a lost closing marker
#     usually hides: a later doc comment closes the licence header, so nothing is
#     unterminated at the end of the file, but everything between is swallowed.
#     A lost close is therefore only found if a /* starts a line later inside it;
#     with no such comment after it the file is just one long comment and only
#     the type-load pass of qml-smoke.sh sees the result (types unavailable),
#   - a "..." or single-quoted string that ends with its line (the line of the quote),
#   - a template or raw string still open at the end of the file.
#
# --self-test runs the scanner over small built-in fixtures that must pass and
# must fail (including the lost licence close, a regex after return, a division
# on a continuation line, and C++ character prefixes); exit 1 if one is wrong.
# COMMENT_LINT_VERBOSE=1 lists every fixture.

set -euo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

case "${1:-}" in
    -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

# --- self-test ----------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
    dir="$(mktemp -d)"
    trap 'rm -rf "$dir"' EXIT
    failures=0
    total=0
    # fixture NAME.EXT pass|fail   (the content is read from stdin)
    fixture() {
        local file="$dir/$1" expect="$2" rc=0
        cat > "$file"
        total=$((total + 1))
        bash "$SELF" "$file" >/dev/null 2>&1 || rc=$?
        if { [ "$expect" = pass ] && [ "$rc" -eq 0 ]; } || { [ "$expect" = fail ] && [ "$rc" -eq 1 ]; }; then
            [ -z "${COMMENT_LINT_VERBOSE:-}" ] || echo "  ok   $1 ($expect)"
        else
            echo "  FAIL $1: expected $expect, the lint exited $rc" >&2
            failures=$((failures + 1))
        fi
    }

    fixture clean_licence.qml pass <<'EOF'
/*****************************************************************************
 * Copyright (C) 2026 VLC Reborn contributors
 *****************************************************************************/
import QtQuick
/**
 * Doc comment.
 */
Item { }
EOF

    fixture apostrophes_in_comments.qml pass <<'EOF'
// don't confuse the scanner
/* it's fine, "too */
Item { property string s: "a // not a comment" }
EOF

    fixture regex_after_return.qml pass <<'EOF'
Item {
    function f(x) { return /'/.test(x) }
}
EOF

    fixture regex_after_keywords.qml pass <<'EOF'
Item {
    function f(x) {
        switch (x) {
        case /"/.test(x): break
        }
        if (typeof /'/ === "object") throw /"/
        var a = x ? /"/ : /'/
        return [/'/, /"/]
    }
}
EOF

    fixture division_on_continuation.qml pass <<'EOF'
Item {
    width: parent.width
        / 2 // don't
    height: 10
}
EOF

    fixture division_after_names.qml pass <<'EOF'
Item {
    property real a: width / 2 / 3 // it's
    property real b: (width) / 2 // it's
    property real c: arr[0] / 2 // it's
}
EOF

    fixture template_string.qml pass <<'EOF'
Item {
    property string s: `multi
        line ${1 + 1} it's`
}
EOF

    fixture cpp_char_prefixes.cpp pass <<'EOF'
const wchar_t a = L'"';
const char16_t b = u'"';
const char32_t c = U'"';
const char8_t d = u8'"';
int e = 1'000'000 + 0x1F'FF;
const char *s = "it's";
EOF

    fixture cpp_directive_text.cpp pass <<'EOF'
#error do not, it's broken
  #  warning "don't" \
     continued, it's still the directive
#define LONG 1 /* a comment that
   spans lines, with an apostrophe: it's fine */
int ok = 'x';
EOF

    fixture cpp_directive_open_comment.cpp fail <<'EOF'
#define A 1 /* opened on a directive line, never closed
int x;
EOF

    fixture cpp_raw_string.cpp pass <<'EOF'
const char *a = R"x(multi "line"
/* not a comment, ' not a string )x";
const char *b = u8R"(also ' ok)";
int c = 1; // done
EOF

    fixture lost_licence_close.qml fail <<'EOF'
/*****************************************************************************
 * Copyright (C) 2026 VLC Reborn contributors
 *****************************************************************************
import QtQuick
/**
 * Doc comment.
 */
Item { }
EOF

    fixture unclosed_at_eof.qml fail <<'EOF'
/* Copyright
import QtQuick
Item { }
EOF

    fixture nested_open.cpp fail <<'EOF'
/* a
/* b */
int x;
EOF

    fixture unterminated_string.qml fail <<'EOF'
Item { property string s: "abc
}
EOF

    fixture unterminated_template.qml fail <<'EOF'
Item { property string s: `abc
}
EOF

    fixture unterminated_after_regex.qml fail <<'EOF'
Item {
    function f(x) { return /'/.test(x); var s = "oops
}
EOF

    fixture unterminated_prefixed_char.cpp fail <<'EOF'
const wchar_t a = L'x;
EOF

    fixture unterminated_raw_string.cpp fail <<'EOF'
const char *a = R"x(never closed
int y;
EOF

    if [ "$failures" -ne 0 ]; then
        echo "comment-lint.sh self-test: $failures of $total fixtures wrong" >&2
        exit 1
    fi
    echo "comment-lint.sh self-test: $total fixtures as expected"
    exit 0
fi

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

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
BEGIN {
    n = split("return typeof case in of void delete throw yield await new instanceof else do", kwlist, " ")
    for (k = 1; k <= n; k++) kw[kwlist[k]] = 1
    ops = "(,=:[!&|?{};+-*%<>~^"      # after one of these a "/" starts a regex
}

function err(f, ln, msg) { printf "%s:%d: %s\n", f, ln, msg; bad++ }

function finish(f) {
    if (inblock) err(f, blockline, "unterminated /* comment (opened here, never closed)")
    if (inbt)    err(f, btline, "unterminated template string (opened here, never closed)")
    if (inraw)   err(f, rawline, "unterminated raw string literal (opened here, never closed)")
    if (instr)   err(f, strline, "unterminated string literal at end of file")
    inblock = inbt = inraw = instr = nested = 0
}

function isword(ch) { return ch ~ /^[A-Za-z0-9_$]$/ }

FNR == 1 {
    if (cur != "") finish(cur)
    cur = FILENAME
    isqml = (FILENAME ~ /\.qml$/)
    prev = ""            # last significant character (not space, not in a comment)
    lastword = ""        # the last identifier or number token
}

{
    line = $0
    sub(/\r$/, "", line)
    n = length(line)
    i = 1
    # C++ preprocessor directive (a line whose first character is #, and its
    # backslash continuations): its text is not C++ source (#error don\047t ...), so
    # quotes are ignored in it; comments still count (a /* opened here is tracked)
    if (!isqml && !inblock && !inraw && !instr) {
        dir = dircont || (line ~ /^[ \t]*#/)
        dircont = dir && (line ~ /\\$/)
    } else {
        dir = 0; dircont = 0
    }
    while (i <= n) {
        if (inblock) {
            # a comment that opens at the start of a line inside a comment: the
            # first one lost its closing marker (a later */ would close it silently)
            if (i == 1 && line ~ /^[ \t]*\/\*/ && !nested) {
                err(cur, FNR, "/* starts inside the comment opened at line " blockline " (is its closing marker missing?)")
                nested = 1
            }
            j = index(substr(line, i), "*/")
            if (j == 0) { i = n + 1 } else { i += j + 1; inblock = 0; nested = 0 }
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
        if (dir && (c == "\"" || c == "\047")) { i++; continue }
        if (c ~ /[A-Za-z_$]/) {       # identifier (or a string prefix such as L u8 R)
            j = i + 1
            while (j <= n && isword(substr(line, j, 1))) j++
            lastword = substr(line, i, j - i)
            prev = substr(lastword, length(lastword))
            i = j
            continue
        }
        if (c ~ /[0-9]/) {            # numeric token; in C++ it may hold 1\047000 separators
            j = i + 1
            while (j <= n) {
                d = substr(line, j, 1)
                if (d ~ /[0-9A-Za-z_.]/) j++
                else if (d == "\047" && !isqml && j < n && substr(line, j + 1, 1) ~ /[0-9A-Za-z]/) j++
                else break
            }
            lastword = "0"; prev = "0"
            i = j
            continue
        }
        if (c == "\"") {
            if (!isqml && i > 1 && isword(substr(line, i - 1, 1)) && lastword ~ /^(u8|u|U|L)?R$/) {
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
            instr = 1; q = c; strline = FNR; i++
            if (i > n) { err(cur, strline, "unterminated string literal"); instr = 0 }
            continue
        }
        if (isqml && c == "`") { inbt = 1; btline = FNR; i++; continue }
        if (isqml && c == "/") {
            # a regex literal if an operand cannot come before it
            if (prev == "" || index(ops, prev) > 0 || (isword(prev) && (lastword in kw))) {
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
