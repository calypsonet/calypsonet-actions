#!/bin/sh

echo "Compute the current API version..."

repository_name=$1
version=$2
specification_name=$3

echo "Computed current API version: $version"

echo "Clone $repository_name..."
git clone https://github.com/calypsonet/$repository_name.git

cd $repository_name

echo "Checkout doc branch..."
git checkout -f doc

echo "Delete existing SNAPSHOT directory..."
rm -rf *-SNAPSHOT

echo "Create target directory $version..."
mkdir $version

echo "Copy specification and uml files..."
cp -rf ../gen/api_class_diagram.svg $version/$specification_name.svg
cp -rf ../gen/$specification_name.html $version/
cp -rf ../gen/$specification_name.pdf $version/

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
      echo "| **$directory (latest stable)** | [API class diagram](latest-stable/$specification_name.svg)<br>[API specification (HTML)](latest-stable/$specification_name.html)<br>[API specification (PDF)](latest-stable/$specification_name.pdf) |" >> list_versions.md
  else
      echo "| $directory | [API class diagram]($directory/$specification_name.svg)<br>[API specification (HTML)]($directory/$specification_name.html)<br>[API specification (PDF)]($directory/$specification_name.pdf) |" >> list_versions.md
  fi
done

echo "Computed all versions:"
cat list_versions.md
cd ..
echo "Local docs update finished."