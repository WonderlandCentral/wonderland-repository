#!/bin/bash
set -e

# Function to generate a hash
generate_hash() {
    local file=$1
    local algo=$2
    local suffix=$3

    case "$algo" in
        md5)    hash=$(md5sum "$file" | awk '{print $1}') ;;
        sha1)   hash=$(sha1sum "$file" | awk '{print $1}') ;;
        sha256) hash=$(sha256sum "$file" | awk '{print $1}') ;;
        sha512) hash=$(sha512sum "$file" | awk '{print $1}') ;;
        *) echo "Unknown algorithm: $algo" >&2; return 1 ;;
    esac

    echo "$hash" > "$file.$suffix"
}

# Generate all hash types
generate_all_hashes() {
    local file=$1
    for algo in md5 sha1 sha256 sha512; do
        generate_hash "$file" "$algo" "$algo"
    done
}

# Create the POM file
generate_pom() {
    local pom_path=$1
    local groupId=$2
    local artifactId=$3
    local version=$4

    cat > "$pom_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd" xmlns="http://maven.apache.org/POM/4.0.0"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <modelVersion>4.0.0</modelVersion>
  <groupId>${groupId}</groupId>
  <artifactId>${artifactId}</artifactId>
  <version>${version}</version>
  <description>POM was created from install:install-file</description>
</project>
EOF
}

# Create _remote.repositories
generate_remote_repositories() {
    local repo_file=$1
    local artifact_filename=$2
    local pom_filename=$3

    cat > "$repo_file" <<EOF
$artifact_filename>=
$pom_filename>=
EOF
}

# Root is current directory
ROOT_DIR="$(pwd)"

# Find all .jar files under current directory
find . -type f -name "*.jar" | while read -r jar_path; do
    echo "Processing: $jar_path"

    dir_path=$(dirname "$jar_path")
    filename=$(basename "$jar_path")
    base_name="${filename%.jar}"

    version=$(basename "$dir_path")
    artifactId=$(basename "$(dirname "$dir_path")")

    # Extract relative path from ROOT_DIR
    rel_path="${dir_path#./}"  # remove leading ./
    group_path=$(dirname "$(dirname "$rel_path")")  # e.g., com/viaversion
    groupId=${group_path//\//.}  # replace / with .

    pom_file="${artifactId}-${version}.pom"
    repo_file="_remote.repositories"

    full_pom_path="$dir_path/$pom_file"
    full_repo_path="$dir_path/$repo_file"

    # Generate hashes for .jar
    generate_all_hashes "$jar_path"

    # Generate .pom if missing
    if [[ ! -f "$full_pom_path" ]]; then
        generate_pom "$full_pom_path" "$groupId" "$artifactId" "$version"
        echo "Generated POM: $full_pom_path"
    fi

    # Generate hashes for .pom
    generate_all_hashes "$full_pom_path"

    # Generate _remote.repositories
    generate_remote_repositories "$full_repo_path" "$filename" "$pom_file"
    echo "Generated _remote.repositories: $full_repo_path"
done

