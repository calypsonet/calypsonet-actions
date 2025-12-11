# Calypsonet Reusable Workflows and Composite Actions

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This repository contains all **GitHub Actions** and **reusable workflows** for the `calypsonet` organization. It's structured to separate **custom composite actions**, **reusable workflows**, and to clearly mark **deprecated** items.

---

## 🔁 Reusable Workflows

These workflows can be invoked in any org repository via `workflow_call`.

| Name               | Description                                                      | Path                                                |
|--------------------|------------------------------------------------------------------|-----------------------------------------------------|
| Build and Test     | Build and test Java/Gradle projects with license verification    | `.github/workflows/reusable-build-and-test.yml`     |
| C++ Build and Test | Build and test C++ projects across Linux, macOS, and Windows     | `.github/workflows/reusable-cpp-build-and-test.yml` |
| Publish Snapshot   | Publish snapshot versions to Maven Central                       | `.github/workflows/reusable-publish-snapshot.yml`   |
| Publish Release    | Publish official releases to Maven Central with GPG signing      | `.github/workflows/reusable-publish-release.yml`    |
| Publish Doxygen    | Generate and publish Doxygen documentation (C++) to `doc` branch | `.github/workflows/reusable-publish-doxygen.yml`    |

**Workflow Logic**:
- **Build and Test**: Sets up Java environment and runs Gradle build.
- **C++ Build and Test**: Builds C++ projects using CMake across three platforms (Linux with GCC, macOS with Clang, Windows with Clang/Visual Studio 2022). Automatically installs required dependencies (clang, cmake, cppcheck, clang-format, clang-tidy, gcc, pre-commit) and supports optional extra Linux dependencies. Runs tests on Linux/macOS if a test executable name is provided.
- **Publish Snapshot**: Validates version is not already released, builds the project, publishes to Maven Central Snapshots, and updates documentation.
- **Publish Release**: Verifies version consistency, signs artifacts with GPG, publishes to Maven Central, triggers automatic upload, and updates documentation.
- **Publish Doxygen**: Extracts repository metadata and invokes the `doxygen` action to generate and deploy documentation.

---

## 🔧 Internal Composite Actions

These actions live under `actions/` and encapsulate reusable complex workflows.

| Name                 | Description                                             | Path                                      | Status     |
|----------------------|---------------------------------------------------------|-------------------------------------------|------------|
| doxygen              | Generate and publish Doxygen documentation (C++ API)    | `actions/doxygen/action.yml`              | **Active** |
| update-documentation | Generate and push Javadoc to `doc` branch               | `actions/update-documentation/action.yml` | **Active** |

**Composite Action Logic**:
- **doxygen**: Installs Python and dependencies, validates and patches Doxyfile, generates documentation via Doxygen, prepares versioned directory structure, deploys to `doc` branch, and triggers centralized documentation update.
- **update-documentation**: Prepares Javadoc via shell script, commits and pushes to `doc` branch, then triggers centralized documentation update.

---

## 📘 Usage Examples

```yaml
name: Publish Snapshot

on:
  push:
    branches: [ main ]

jobs:
  publish:
    uses: calypsonet/calypsonet-actions/.github/workflows/reusable-publish-snapshot.yml@main
    secrets:
      CENTRAL_SONATYPE_TOKEN_USERNAME: ${{ secrets.CENTRAL_SONATYPE_TOKEN_USERNAME }}
      CENTRAL_SONATYPE_TOKEN_PASSWORD: ${{ secrets.CENTRAL_SONATYPE_TOKEN_PASSWORD }}
      ORG_GITHUB_BOT_TOKEN: ${{ secrets.ORG_GITHUB_BOT_TOKEN }}
```

```yaml
name: Build and Test

on:
  pull_request:

jobs:
  build:
    uses: calypsonet/calypsonet-actions/.github/workflows/reusable-build-and-test.yml@main
```

```yaml
name: C++ Build and Test

on:
  pull_request:
  push:
    branches: [ main ]

jobs:
  build:
    uses: calypsonet/calypsonet-actions/.github/workflows/reusable-cpp-build-and-test.yml@main
    with:
      test_executable_name: 'my-test-app'  # Optional: name of the test executable to run
      extra_linux_deps: 'libssl-dev'       # Optional: additional Linux dependencies
```

---

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
