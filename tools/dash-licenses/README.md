# License Check Script

This Python script automates dependency license verification for Gradle-based projects using the Eclipse [dash-licenses](https://github.com/eclipse-dash/dash-licenses) tool. It works on both Windows and Linux/macOS and can optionally create an automatic IP Team Review Request if a library requires further review.

---

## Features

- Generates a Gradle dependency lockfile (`gradle.lockfile`) for your project.
- Downloads and manages the latest `dash-licenses-tool.jar` in the script directory.
- Checks project dependencies for license compliance.
- Optionally submits an IP Team Review Request to Eclipse GitLab.
- Compatible with Windows (no Unix tools required).

---

## Requirements

- Python 3.7+
- Java 17+ in your PATH
- Gradle wrapper (`gradlew` or `gradlew.bat`) in the project directory

Optional for review requests:

- GitLab token with `api` scope
- Committer status on at least one Eclipse project

---

## Usage

1. Navigate to your Gradle project directory:

```bash
cd path/to/your/project
````

2. Run the script:

Basic license check:

```bash
python check-licenses.py
```

Force download of the latest jar:

```bash
python check-licenses.py --force-update
```

Automatic IP Team Review Request:

```bash
python check-licenses.py --review --token YOUR_GITLAB_TOKEN --project iot.eclipse --repo https://github.com/eclipse-keypop/keypop-service-java-lib
```

**Arguments:**

| Argument         | Description                                         |
| ---------------- | --------------------------------------------------- |
| `--force-update` | Always download the latest `dash-licenses-tool.jar` |
| `--review`       | Enable automatic IP Team Review Request             |
| `--token`        | GitLab token (required if `--review`)               |
| `--repo`         | Eclipse project repository URL (optional)           |
| `--project`      | Eclipse project ID (required if `--review`)         |

---

## Output

* `gradle.lockfile`: Generated lockfile with dependencies.
* `dash-summary.txt`: Summary of license check results.
* `dash-licenses-tool.jar`: The tool stored in the script directory (versioned).

---

## Notes

* `init.gradle.kts` is created temporarily and removed automatically.
* On Windows, the script uses `gradlew.bat` and requires no Unix utilities.
* The script maintains a `.version` file to track the last downloaded version of the jar.