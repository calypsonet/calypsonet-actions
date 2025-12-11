#!/usr/bin/env python3

import argparse
import re
import logging
from pathlib import Path
from typing import Optional

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class VersionError(Exception):
    """Custom exception for version-related errors"""
    pass

class DoxyfileUpdater:
    def __init__(self):
        self.version_pattern = re.compile(r'^\d+\.\d+\.\d+(?:\.\d+)?$')

    def validate_version(self, version: str) -> bool:
        """Validate version string format"""
        return bool(self.version_pattern.match(version))

    def _parse_project_name(self, readme_file: Path) -> str:
        """
        Extract project name from README.md first line

        Args:
            readme_file: Path to README.md

        Returns:
            str: Project name extracted from first line

        Raises:
            FileNotFoundError: If README.md doesn't exist
            ValueError: If project name cannot be extracted
        """
        if not readme_file.exists():
            raise FileNotFoundError(f"README.md not found at {readme_file}")

        try:
            with readme_file.open('r', encoding='utf-8') as f:
                first_line = f.readline().strip()
        except IOError as e:
            raise IOError(f"Failed to read README.md: {e}")

        # Remove # characters and strip whitespace
        project_name = first_line.replace('#', '').strip()

        if not project_name:
            raise ValueError("Could not extract project name from README.md first line")

        logger.info(f"Extracted project name: {project_name}")
        return project_name

    def _parse_cmake_version(self, cmake_file: Path) -> str:
        """
        Extract version from CMakeLists.txt

        Args:
            cmake_file: Path to CMakeLists.txt

        Returns:
            str: Full version string, including C++ fix if present

        Raises:
            FileNotFoundError: If CMakeLists.txt doesn't exist
            VersionError: If version cannot be extracted
        """
        if not cmake_file.exists():
            raise FileNotFoundError(f"CMakeLists.txt not found at {cmake_file}")

        content = cmake_file.read_text()

        project_version_pattern = r'PROJECT\s*\([^)]*VERSION\s+(\d+\.\d+\.\d+)[^)]*\)'
        version_match = re.search(project_version_pattern, content, re.MULTILINE | re.IGNORECASE)

        if not version_match:
            raise VersionError("Could not extract PROJECT VERSION")

        version = version_match.group(1)

        # Check for C++ fix version
        cpp_fix_pattern = r'SET\s*\(VERSION_CPPFIX\s*"(\d+)"\s*\)'
        cpp_fix_match = re.search(cpp_fix_pattern, content)

        if cpp_fix_match:
            version = f"{version}.{cpp_fix_match.group(1)}"

        if not self.version_pattern.match(version):
            raise VersionError(f"Invalid version format: {version}")

        return version

    def update_doxyfile(self, doxyfile_path: Path, version: Optional[str] = None) -> None:
        """
        Update Doxyfile with current version and project name

        Args:
            doxyfile_path: Path to the Doxyfile
            version: Optional version string, if not provided will use version from CMakeLists.txt

        Raises:
            FileNotFoundError: If Doxyfile doesn't exist
            VersionError: If version is invalid or cannot be extracted
        """
        logger.info("Computing current API version...")

        if version and not self.validate_version(version):
            raise VersionError(f"Invalid version format: {version}")

        if not version:
            # Use version from CMakeLists.txt
            version = self._parse_cmake_version(Path("CMakeLists.txt"))

        logger.info(f"Using API version: {version}")

        # Extract project name from README.md
        logger.info("Extracting project name from README.md...")
        project_name = self._parse_project_name(Path("README.md"))

        if not doxyfile_path.exists():
            raise FileNotFoundError(f"Doxyfile not found at {doxyfile_path}")

        try:
            content = doxyfile_path.read_text()
            updated_content = content.replace("%PROJECT_VERSION%", version)
            updated_content = updated_content.replace("%PROJECT_NAME%", project_name)
            doxyfile_path.write_text(updated_content)
            logger.info(f"Updated {doxyfile_path} with version {version} and project name {project_name}")
        except IOError as e:
            raise IOError(f"Failed to update Doxyfile: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Update Doxyfile version and project name from README.md")
    parser.add_argument("doxyfile_path", type=Path, help="Path to the Doxyfile")
    parser.add_argument("version", nargs="?", help="Version to set (optional, will use CMakeLists.txt if not provided)")
    args = parser.parse_args()

    try:
        updater = DoxyfileUpdater()
        updater.update_doxyfile(args.doxyfile_path, args.version)
    except Exception as e:
        logger.error(str(e))
        raise SystemExit(1)