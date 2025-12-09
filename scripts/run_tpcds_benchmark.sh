#!/usr/bin/env bash
set -euo pipefail

# Simple orchestrator for running DuckDB TPC-DS benchmarks in Docker
# - Prompts for scale factor
# - Creates a persistent DuckDB database file on the host
# - Waits for user input before running a set of TPC-DS queries

IMAGE_NAME="duckdb-tpcds"
DATA_DIR="$(pwd)/duckdb-data"

mkdir -p "${DATA_DIR}"

read -rp "Enter TPC-DS scale factor (e.g. 1, 10, 100): " SF
if [[ -z "${SF}" ]]; then
  echo "Scale factor cannot be empty" >&2
  exit 1
fi

DB_FILE="tpcds_sf${SF}.duckdb"
DB_PATH_HOST="${DATA_DIR}/${DB_FILE}"

echo "\n[1/3] Building DuckDB image '${IMAGE_NAME}' (from official duckdb/duckdb) ..."
# We directly use the official DuckDB image; no custom Dockerfile required.
# This build just creates a lightweight tagged image so the script has a stable name.
cat <<'EOF' | docker build -t "${IMAGE_NAME}" -
FROM duckdb/duckdb:latest
WORKDIR /workspace
RUN ["duckdb", "-c", "INSTALL tpcds;"]
EOF

if [[ -f "${DB_PATH_HOST}" ]]; then
  echo "\nDatabase file already exists: ${DB_PATH_HOST}"
  echo "Skipping TPC-DS data generation and reusing existing database."
else
  echo "\n[2/3] Generating TPC-DS data at scale factor ${SF} into ${DB_PATH_HOST} ..."
  # This creates a persistent on-disk database file under ./duckdb-data
  # so that data is not kept purely in memory.
  docker run --rm \
    -v "${DATA_DIR}":/data \
    "${IMAGE_NAME}" \
    duckdb /data/"${DB_FILE}" -c "LOAD tpcds; CALL dsdgen(sf=${SF});"

  echo "\nDatabase created: ${DB_PATH_HOST}"
fi

echo "\n[3/3] Press Enter to start benchmark queries (this may stress memory/IO) ..."
read -r _

echo "Running TPC-DS queries 1 to 99 in order ..."

# Build a single SQL string that loads the extension and
# calls all TPC-DS queries from 1 to 99 in sequence.
SQL="LOAD tpcds;"
for q in $(seq 1 99); do
  SQL+=" PRAGMA tpcds(${q});"
done

# We reopen the same on-disk database file and run all TPC-DS queries.
docker run --rm \
  -v "${DATA_DIR}":/data \
  "${IMAGE_NAME}" \
  duckdb /data/"${DB_FILE}" -c "${SQL}"

echo "\nBenchmark run finished. You can inspect memory/swap on the host while it runs."
