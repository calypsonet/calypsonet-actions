#!/bin/sh

echo "Compute the current API version..."

repo_name=$1
spec_version=$2
spec_full_name=$3

echo "Computed current API version: $spec_version"

echo "Clone $repo_name..."
git clone https://github.com/calypsonet/$repo_name.git

cd $repo_name

echo "Checkout doc branch..."
git checkout -f doc

echo "Delete existing SNAPSHOT directory..."
rm -rf *-SNAPSHOT

echo "Create target directory $spec_version..."
mkdir $spec_version

echo "Copy specification and uml files..."
cp -rf ../generated/class-diagram.svg $spec_version/
cp -rf ../generated/$spec_full_name.html $spec_version/
cp -rf ../generated/$spec_full_name.pdf $spec_version/

# Find the latest stable version (first non-SNAPSHOT)
latest_stable=$(ls -d [0-9]*/ | grep -v SNAPSHOT | cut -f1 -d'/' | sort -Vr | head -n1)

# Create latest-stable copy if we have a stable version
if [ ! -z "$latest_stable" ]; then
    echo "Creating latest-stable directory pointing to $latest_stable..."
    rm -rf latest-stable
    mkdir latest-stable
    cp -rf "$latest_stable"/* latest-stable/
fi

echo "Update versions list..."
echo "| Version | Documents |" > list_versions.md
echo "|:---:|---|" >> list_versions.md

# Get the list of directories sorted by version number
sorted_dirs=$(ls -d [0-9]*/ | cut -f1 -d'/' | sort -Vr)

# Loop through each sorted directory
for directory in $sorted_dirs
do
  # If this is the stable version, write latest-stable entry first
  if [ "$directory" = "$latest_stable" ]; then
      echo "| **$directory (latest stable)** | [API class diagram](latest-stable/class-diagram.svg)<br>[API specification (HTML)](latest-stable/$spec_full_name.html)<br>[API specification (PDF)](latest-stable/$spec_full_name.pdf) |" >> list_versions.md
  else
      echo "| $directory | [API class diagram]($directory/class-diagram.svg)<br>[API specification (HTML)]($directory/$spec_full_name.html)<br>[API specification (PDF)]($directory/$spec_full_name.pdf) |" >> list_versions.md
  fi
done

echo "Computed all versions:"
cat list_versions.md
cd ..
echo "Local docs update finished."