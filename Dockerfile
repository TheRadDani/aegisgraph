# syntax=docker/dockerfile:1.4

# Multi-stage build for efficient Python wheel packaging
ARG PYTHON_VERSION=3.12
ARG BASE_IMAGE=python:${PYTHON_VERSION}-slim-bookworm

# =================== Builder Stage ===================
FROM ${BASE_IMAGE} AS builder

# Install build dependencies
RUN apt-get update && \
    apt-get install -y wget gnupg && \
    wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - && \
    echo "deb http://apt.llvm.org/bookworm/ llvm-toolchain-bookworm-16 main" >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    git \
    wget \
    curl \
    ninja-build \
    libabsl-dev \
    libpython3-dev \
    pkg-config \
    binutils-gold \
    && rm -rf /var/lib/apt/lists/*

# Install modern CMake (3.28+)
RUN curl -L https://github.com/Kitware/CMake/releases/download/v4.0.0/cmake-4.0.0-linux-x86_64.tar.gz | tar xz -C /usr/local --strip-components=1

RUN useradd -m builder
USER builder
WORKDIR /home/builder/app

COPY --chown=builder:builder . .

RUN pip install --user -U pip setuptools wheel && \
    pip install --user scikit-build-core \
    pybind11 \
    build

RUN python -m build --wheel --no-isolation \
    -Ccmake.define.CMAKE_BUILD_TYPE=Release \
    -Ccmake.define.CMAKE_EXE_LINKER_FLAGS="-fuse-ld=gold" \
    -Ccmake.define.CMAKE_SHARED_LINKER_FLAGS="-fuse-ld=gold" \

# =================== Final Stage ===================
FROM ${BASE_IMAGE} AS runtime

WORKDIR /app

COPY --from=builder --chown=1000:1000 /home/builder/app/dist/*.whl ./

# Install runtime dependencies (if any)
RUN pip install --no-cache-dir $(ls *.whl)[test] && \
    rm -f *.whl

# Optional: Set entrypoint for testing
ENTRYPOINT ["python"]