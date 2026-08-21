# Upstream provenance

This directory does not vendor the upstream source tree or compiled binaries.
The build script fetches and verifies these exact Git commits:

| Component | Repository | Commit |
|---|---|---|
| `upgrade_tool` | <https://github.com/bitshelf/upgrade_tool> | `ea51edd64f72b338c1d6adb9c21693712f38bd83` |
| `libudev-zero` | <https://github.com/illiliti/libudev-zero> | `ee32ac5f6494047b9ece26e7a5920650cdf46655` (`1.0.3`) |

At the pinned `upgrade_tool` commit, `main.cpp` contains a GPL-3.0-or-later
notice, but the upstream repository has no top-level `LICENSE` or `COPYING`
file. Confirm the upstream licensing status before redistributing its source or
compiled binary. The documentation and helper scripts here do not attempt to
replace or reinterpret upstream license terms.
