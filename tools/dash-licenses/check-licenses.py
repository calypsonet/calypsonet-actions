#!/usr/bin/env python3
import subprocess
import os
import shutil
import urllib.request
import logging
from pathlib import Path
import argparse

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")

SCRIPT_DIR = Path(__file__).resolve().parent
DASH_JAR_NAME = "dash-licenses-tool.jar"
DASH_JAR_URL = (
    "https://repo.eclipse.org/service/local/artifact/maven/redirect"
    "?r=dash-licenses&g=org.eclipse.dash&a=org.eclipse.dash.licenses&v=LATEST"
)

def run_cmd(cmd, cwd=None, check=True):
    logging.info(f"Running: {' '.join(cmd)}")
    subprocess.run(cmd, cwd=cwd, check=check, shell=(os.name == "nt"))

def ensure_dash_tool(force_update=False):
    logging.info("Checking dash-licenses-tool (LATEST)...")
    with urllib.request.urlopen(DASH_JAR_URL) as resp:
        final_url = resp.geturl()
    jar_filename = Path(final_url).name
    jar_path = SCRIPT_DIR / jar_filename
    version_file = SCRIPT_DIR / (DASH_JAR_NAME + ".version")

    current_version = version_file.read_text().strip() if version_file.exists() else None

    if force_update or current_version != jar_filename or not jar_path.exists():
        logging.info("Downloading new version of dash-licenses-tool...")
        urllib.request.urlretrieve(final_url, jar_path)
        version_file.write_text(jar_filename)
        logging.info(f"Downloaded {jar_filename} and updated version file")
    else:
        logging.info(f"Jar already up-to-date: {jar_filename}")

    symlink_path = SCRIPT_DIR / DASH_JAR_NAME
    if symlink_path.exists():
        symlink_path.unlink()
    try:
        symlink_path.symlink_to(jar_path.name)
    except OSError:
        shutil.copyfile(jar_path, symlink_path)

    return symlink_path

def get_gradle_cmd(project_dir: Path):
    gradlew = project_dir / ("gradlew.bat" if os.name == "nt" else "gradlew")
    if not gradlew.exists():
        raise FileNotFoundError(f"{gradlew} not found in project directory")
    return [str(gradlew)]

def generate_lockfile(project_dir: Path):
    init_script = project_dir / "init.gradle.kts"
    logging.info("Creating init.gradle.kts for dependency locking...")
    init_script.write_text("allprojects { dependencyLocking { lockAllConfigurations() } }")
    logging.info("Generating gradle.lockfile...")
    run_cmd(get_gradle_cmd(project_dir) + ["dependencies", "--write-locks", "--init-script", str(init_script)], cwd=project_dir)

def read_dependencies_from_lockfile(gradle_lockfile: Path):
    """Extract dependencies from gradle.lockfile."""
    logging.info("Extracting dependencies from gradle.lockfile...")
    dependencies = []
    with open(gradle_lockfile, "r", encoding="utf-8") as infile:
        for line in infile:
            line = line.strip()
            if not line or line.startswith("#") or line.startswith("empty"):
                continue
            dependencies.append(line.split("=", 1)[0])

    if not dependencies:
        logging.warning("No dependencies found in gradle.lockfile!")
    return dependencies

def build_dash_command(dash_jar: Path, summary_file: Path, review: bool, token: str, repo: str, project: str):
    """Build the dash-licenses command."""
    cmd = ["java", "-jar", str(dash_jar), "-summary", str(summary_file), "-"]
    if review:
        if not token or not project:
            raise ValueError("Token and project are required when --review is enabled")
        cmd += ["-review", "-token", token, "-project", project]
        if repo:
            cmd += ["-repo", repo]
    return cmd

def handle_dash_result(proc):
    """Handle the result from dash-licenses tool."""
    stdout_text = proc.stdout.decode()
    stderr_text = proc.stderr.decode()

    if proc.returncode == 0:
        logging.info("License check completed successfully")
    elif proc.returncode in (3, 4):
        logging.warning("License check completed with items requiring review or unverified dependencies")
        logging.info(stdout_text)
        if stderr_text:
            logging.warning(stderr_text)
    else:
        logging.error("License check failed with unexpected error code")
        logging.error(stdout_text)
        logging.error(stderr_text)
        raise subprocess.CalledProcessError(proc.returncode, proc.args, proc.stdout, proc.stderr)

def run_dash_tool(project_dir: Path, review=False, token=None, repo=None, project=None):
    summary_file = project_dir / "dash-summary.txt"
    gradle_lockfile = project_dir / "gradle.lockfile"
    dash_jar = SCRIPT_DIR / DASH_JAR_NAME

    if not gradle_lockfile.exists():
        raise FileNotFoundError("gradle.lockfile not found. Did you run generate_lockfile()?")

    dependencies = read_dependencies_from_lockfile(gradle_lockfile)
    if not dependencies:
        return

    cmd = build_dash_command(dash_jar, summary_file, review, token, repo, project)
    logging.info(f"Running dash-licenses{' with review request' if review else ''}...")

    proc = subprocess.run(
        cmd,
        input="\n".join(dependencies).encode("utf-8"),
        cwd=project_dir,
        capture_output=True
    )

    handle_dash_result(proc)

def clean_up(project_dir: Path):
    init_script = project_dir / "init.gradle.kts"
    if init_script.exists():
        logging.info("Removing init.gradle.kts")
        init_script.unlink()

def main():
    parser = argparse.ArgumentParser(description="Check dependencies and optionally request IP Team review")
    parser.add_argument("--force-update", action="store_true", help="Force download the latest dash-licenses-tool.jar")
    parser.add_argument("--review", action="store_true", help="Enable automatic IP Team Review Request")
    parser.add_argument("--token", type=str, help="GitLab token (required if --review)")
    parser.add_argument("--repo", type=str, help="Eclipse project repo URL (optional)")
    parser.add_argument("--project", type=str, help="Eclipse project ID (required if --review)")
    args = parser.parse_args()

    project_dir = Path.cwd()
    logging.info(f"Working in project directory: {project_dir}")

    try:
        ensure_dash_tool(force_update=args.force_update)
        generate_lockfile(project_dir)
        run_dash_tool(project_dir, review=args.review, token=args.token, repo=args.repo, project=args.project)
    finally:
        clean_up(project_dir)

if __name__ == "__main__":
    main()
