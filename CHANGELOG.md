# CHANGELOG.md

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2025-03-27
### Added
- Initial public release of `aegisgraph`.
- High-performance C++ backend using memory-mapped file parsing and SIMD for loading edge lists.
- Python bindings via `pybind11`, exposing core methods.
- Graph methods:
  - `load_edges(filepath)`
  - `get_neighbors(node)`
  - `add_node(node)`
  - `delete_node(node)`
  - `random_walk(start_node, walk_length, num_walks)`
  - `save_graph(filename)`
- Memory-efficient adjacency list representation.
- Secure filepath validation to prevent directory traversal.
- Random walk engine implemented with stack-local walkers.
- Unit test support using `pytest`.
- CMake-based build system with LTO, OpenMP, and security flags.
- PyPI-ready build via `scikit-build-core`.
- Continuous Integration with GitHub Actions.
- Automated Doxygen documentation publishing to GitHub Pages.

---

## [Unreleased]
### Planned
- Weighted edge support.
- Directed/undirected mode toggle.
- Graph visualization export (Graphviz/DOT).
- Graph algorithms: BFS, DFS, shortest path (Dijkstra/A*).
- Cython + GPU extension module for even faster processing.

---