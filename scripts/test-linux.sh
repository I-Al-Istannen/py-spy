#!/usr/bin/env bash
# Runs the py-spy test suite on Linux through Docker (e.g. from macOS).
#
# Mirrors .github/workflows/build.yml: `cargo test` (here with the `unwind`
# feature, so the native unwinding tests run too) followed by
# tests/integration_test.py against the freshly built py-spy binary.
#
# The source tree is mounted read-only; build output and the cargo registry
# live in docker volumes so repeated runs are incremental.
#
# Usage: scripts/test-linux.sh [extra cargo test args...]
#   e.g. scripts/test-linux.sh --test integration_test test_native_all
#
# Set SKIP_PY_INTEGRATION=1 to only run `cargo test`.
set -euo pipefail

cd "$(dirname "$0")/.."

IMAGE=py-spy-test-linux

# Image with the build dependencies, so apt only runs when this changes.
# python-is-python3: the rust integration tests spawn `python`.
# python3-numpy: tests/scripts/local_vars.py (CI installs numpy>=2 via pip).
docker build -q -t "$IMAGE" - >/dev/null <<'DOCKERFILE'
FROM rust:1
RUN apt-get update -qq \
    && apt-get install -y -qq --no-install-recommends \
        libunwind-dev liblzma-dev python3 python-is-python3 python3-numpy \
    && rm -rf /var/lib/apt/lists/*
DOCKERFILE

# SYS_PTRACE + unconfined seccomp: the tests attach to other processes
# (process_vm_readv / ptrace). The container runs as root.
docker run --rm \
    --cap-add SYS_PTRACE --security-opt seccomp=unconfined \
    -v "$PWD":/src:ro \
    -v py-spy-target:/target \
    -v py-spy-cargo-registry:/usr/local/cargo/registry \
    -v py-spy-cargo-git:/usr/local/cargo/git \
    -e CARGO_TARGET_DIR=/target \
    -e CARGO_TERM_COLOR="${CARGO_TERM_COLOR:-always}" \
    -e SKIP_PY_INTEGRATION="${SKIP_PY_INTEGRATION:-}" \
    -w /src \
    "$IMAGE" \
    bash -euo pipefail -c '
        cargo test --features unwind "$@"
        if [ -z "$SKIP_PY_INTEGRATION" ] && [ "$#" -eq 0 ]; then
            cargo build --features unwind --bin py-spy
            PATH="/target/debug:$PATH" python3 tests/integration_test.py
        fi
    ' bash "$@"
