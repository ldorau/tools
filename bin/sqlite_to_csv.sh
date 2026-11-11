#!/usr/bin/env bash
#
# sqlite_to_csv.sh - Convert an SQLite database (e.g. a browser "History" file)
# to one or more CSV files, using ';' as the field separator by default.
#
# Usage:
#   ./sqlite_to_csv.sh <input.db> <output.csv> [table_or_query] [separator]
#
# Examples:
#   # Auto-detect a Chromium/Opera "History" DB and export a flattened,
#   # human-readable visit history (urls + visits joined, timestamps decoded):
#   ./sqlite_to_csv.sh piter-BHistory history.csv
#
#   # Export a specific table as-is:
#   ./sqlite_to_csv.sh piter-BHistory downloads.csv downloads
#
#   # Export the result of a custom SQL query:
#   ./sqlite_to_csv.sh piter-BHistory search_terms.csv \
#       "SELECT term, normalized_term FROM keyword_search_terms"
#
#   # Export ALL tables in the database into separate CSV files
#   # (output.csv is then used as a directory):
#   ./sqlite_to_csv.sh piter-BHistory ./csv_export --all
#
#   # Use a different separator (default is ';'):
#   ./sqlite_to_csv.sh piter-BHistory history.csv "" ","
#
set -euo pipefail

usage() {
    grep '^#' "$0" | sed -n '2,/^set -e/p' | sed '$d' | sed 's/^# \{0,1\}//'
    exit 1
}

if [[ $# -lt 2 ]]; then
    usage
fi

DB_PATH="$1"
OUT_PATH="$2"
TABLE_OR_QUERY="${3:-}"
SEPARATOR="${4:-;}"

if [[ ! -f "$DB_PATH" ]]; then
    echo "Error: input database not found: $DB_PATH" >&2
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 is required but not found in PATH." >&2
    exit 1
fi

export SQLITE_TO_CSV_DB="$DB_PATH"
export SQLITE_TO_CSV_OUT="$OUT_PATH"
export SQLITE_TO_CSV_QUERY="$TABLE_OR_QUERY"
export SQLITE_TO_CSV_SEP="$SEPARATOR"

python3 <<'PYEOF'
import csv
import os
import sqlite3
import sys
from datetime import datetime, timedelta

db_path = os.environ["SQLITE_TO_CSV_DB"]
out_path = os.environ["SQLITE_TO_CSV_OUT"]
query_or_table = os.environ.get("SQLITE_TO_CSV_QUERY", "")
sep = os.environ.get("SQLITE_TO_CSV_SEP", ";")

conn = sqlite3.connect(db_path)
cur = conn.cursor()


def table_exists(name):
    cur.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (name,)
    )
    return cur.fetchone() is not None


def chrome_time_to_str(t):
    """Convert a Chromium/WebKit timestamp (microseconds since 1601-01-01) to
    a human-readable string. Falls back to the raw value if it doesn't look
    like a plausible Chromium timestamp."""
    if not t:
        return ""
    try:
        dt = datetime(1601, 1, 1) + timedelta(microseconds=t)
        if 1970 <= dt.year <= 2100:
            return dt.strftime("%Y-%m-%d %H:%M:%S")
    except (OverflowError, OSError, ValueError):
        pass
    return str(t)


def format_duration_hhmmss(us):
    """Convert a duration in microseconds (e.g. visits.visit_duration) to an
    'HH:MM:SS' string. Hours are not wrapped at 24, so durations longer than a
    day are still represented correctly (e.g. '26:00:00')."""
    if not us:
        return "00:00:00"
    total_seconds = int(us) // 1_000_000
    sign = "-" if total_seconds < 0 else ""
    total_seconds = abs(total_seconds)
    hours, rem = divmod(total_seconds, 3600)
    minutes, seconds = divmod(rem, 60)
    return f"{sign}{hours:02d}:{minutes:02d}:{seconds:02d}"


def sanitize_cell(value):
    """csv.writer chokes on two kinds of values found in real browser history
    DBs:
      1. Raw BLOB columns (e.g. downloads.hash) come back as Python bytes.
      2. Some columns declared TEXT actually store raw binary (e.g. downloads.
         embedder_download_data is a serialized protobuf), which arrives as a
         str containing NUL bytes / control characters the csv module can't
         escape ("need to escape, but no escapechar set").
    Render either case as a hex string instead of raising.
    """
    if isinstance(value, (bytes, bytearray)):
        return value.hex()
    if isinstance(value, str) and "\x00" in value:
        return value.encode("utf-8", "surrogatepass").hex()
    return value


def export_query(sql, params, dest_csv):
    cur.execute(sql, params)
    cols = [d[0] for d in cur.description]
    os.makedirs(os.path.dirname(os.path.abspath(dest_csv)) or ".", exist_ok=True)
    with open(dest_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, delimiter=sep)
        writer.writerow(cols)
        n = 0
        for row in cur:
            writer.writerow([sanitize_cell(v) for v in row])
            n += 1
    print(f"Wrote {n} rows to {dest_csv}")


def export_table_raw(table, dest_csv):
    export_query(f"SELECT * FROM {table}", (), dest_csv)


def export_browser_history(dest_csv):
    """Special-case export for Chromium/Opera-style 'History' databases:
    join visits + urls and decode timestamps into readable datetimes."""
    cur.execute(
        """
        SELECT v.id AS visit_id,
               v.visit_time AS visit_time_raw,
               u.url,
               u.title,
               u.visit_count,
               u.typed_count,
               v.visit_duration AS visit_duration_us,
               v.transition,
               v.from_visit
        FROM visits v
        JOIN urls u ON v.url = u.id
        ORDER BY v.visit_time ASC
        """
    )
    rows = cur.fetchall()
    os.makedirs(os.path.dirname(os.path.abspath(dest_csv)) or ".", exist_ok=True)
    with open(dest_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, delimiter=sep)
        writer.writerow(
            [
                "visit_id",
                "visit_time",
                "url",
                "title",
                "visit_count",
                "typed_count",
                "visit_duration",
                "transition",
                "from_visit",
            ]
        )
        for (
            visit_id,
            visit_time_raw,
            url,
            title,
            visit_count,
            typed_count,
            visit_duration_us,
            transition,
            from_visit,
        ) in rows:
            writer.writerow(
                [
                    visit_id,
                    chrome_time_to_str(visit_time_raw),
                    url,
                    title or "",
                    visit_count,
                    typed_count,
                    format_duration_hhmmss(visit_duration_us),
                    transition,
                    from_visit,
                ]
            )
    print(f"Wrote {len(rows)} rows to {dest_csv}")


def export_all_tables(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    cur.execute(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name NOT LIKE 'sqlite_%' ORDER BY name"
    )
    tables = [r[0] for r in cur.fetchall()]
    for t in tables:
        dest = os.path.join(out_dir, f"{t}.csv")
        export_table_raw(t, dest)


if query_or_table == "--all":
    export_all_tables(out_path)
elif query_or_table.strip().lower().startswith("select"):
    export_query(query_or_table, (), out_path)
elif query_or_table:
    if not table_exists(query_or_table):
        print(f"Error: table '{query_or_table}' does not exist in {db_path}", file=sys.stderr)
        cur.execute(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
        )
        print("Available tables:", ", ".join(r[0] for r in cur.fetchall()), file=sys.stderr)
        sys.exit(1)
    export_table_raw(query_or_table, out_path)
else:
    # No table/query given: auto-detect a browser history DB (urls + visits),
    # otherwise fall back to exporting the only table, or list tables.
    if table_exists("urls") and table_exists("visits"):
        export_browser_history(out_path)
    else:
        cur.execute(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name NOT LIKE 'sqlite_%' ORDER BY name"
        )
        tables = [r[0] for r in cur.fetchall()]
        if len(tables) == 1:
            export_table_raw(tables[0], out_path)
        else:
            print(
                "No table/query specified and multiple tables found. "
                "Specify a table name, a SQL query, or '--all' to export every table.",
                file=sys.stderr,
            )
            print("Available tables:", ", ".join(tables), file=sys.stderr)
            sys.exit(1)

conn.close()
PYEOF
