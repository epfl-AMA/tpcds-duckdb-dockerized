# DuckDB TPC-DS benchmark runner

This repository contains a minimal setup to run DuckDB's TPC-DS
extension inside Docker, with data stored on disk and a simple
script to drive the workload. It is designed to study memory usage
and swapping rather than precise query runtimes.

## Prerequisites

- Docker installed and running (e.g. Docker Desktop on macOS/Linux)
- A POSIX shell to run the script (e.g. `bash`)

## Repository layout

- `scripts/run_tpcds_benchmark.sh` – main orchestrator script
- `duckdb-data/` – directory where DuckDB database files are stored
  (created automatically and ignored by Git)

## What the script does

The script `scripts/run_tpcds_benchmark.sh` performs three steps:

1. **Build a small DuckDB image**

   - Tags the image as `duckdb-tpcds` based on `duckdb/duckdb:latest`.
   - Installs the `tpcds` extension inside the image:
     `RUN ["duckdb", "-c", "INSTALL tpcds;"]`.

2. **Generate TPC-DS data on disk**

   - Prompts for a **scale factor** (e.g. `1`, `10`, `100`).
   - Creates a DuckDB database file on disk under `./duckdb-data/`:
     `tpcds_sf<SF>.duckdb`.
   - Runs inside a container:
     - `LOAD tpcds;`
     - `CALL dsdgen(sf=<scale_factor>);`
   - If the database file already exists, data generation is **skipped**
     and the existing file is reused.

3. **Run the TPC-DS query workload**
   - Waits for you to press Enter (so you can get ready to observe
     memory/swap on the host).
   - Reopens the same on-disk database file inside a new container.
   - Executes, in order, **all TPC-DS queries 1 to 99** using the
     `tpcds` extension (via `PRAGMA tpcds(<query_no>);`).
   - All data and metadata stay in the on-disk DuckDB file under
     `./duckdb-data/`, so the workload stresses disk I/O and memory
     usage rather than in-memory-only tables.

## How to run the benchmark

From the repository root:

```bash
cd /path/to/tpcds-duckdb-dockerized
bash scripts/run_tpcds_benchmark.sh
```

You will see prompts like:

1. **Scale factor**
   ```text
   Enter TPC-DS scale factor (e.g. 1, 10, 100): 10
   ```
2. **Data generation (only if DB does not yet exist)**
   ```text
   [2/3] Generating TPC-DS data at scale factor 10 into .../duckdb-data/tpcds_sf10.duckdb ...
   ```
3. **Pause before queries**
   ```text
   [3/3] Press Enter to start benchmark queries (this may stress memory/IO) ...
   ```

Press Enter to start the query workload (queries 1–99).

While the queries are running, you can monitor **memory and swap**
usage for the Docker VM or host using your preferred tools
(e.g. `top`, `htop`, Docker Desktop stats, etc.).

## Re-running with a different scale factor

- To **reuse** an existing database for the same scale factor, simply
  run the script again and enter the same scale factor. Data generation
  will be skipped, and only the queries will run.
- To **regenerate** the database for a given scale factor, delete the
  corresponding file first, for example for scale factor 10:

  ```bash
  rm duckdb-data/tpcds_sf10.duckdb
  bash scripts/run_tpcds_benchmark.sh
  ```

## Notes

- All DuckDB database files are stored under `duckdb-data/` and are
  excluded from Git via `.gitignore`.
- The focus of this setup is **memory and swap behavior** under a
  realistic TPC-DS workload, not micro-optimizing query runtimes.
- You can adapt the script to change which queries run, add multiple
  passes, or interleave additional monitoring/metrics collection
  outside the container.
