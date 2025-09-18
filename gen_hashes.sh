#!/bin/bash
set -e

# Function to generate a hash (returns the hash, doesn't write file)
compute_hash() {
    local file=$1
    local algo=$2

    case "$algo" in
        md5)    md5sum "$file" | awk '{print $1}' ;;
        sha1)   sha1sum "$file" | awk '{print $1}' ;;
        sha256) sha256sum "$file" | awk '{print $1}' ;;
        sha512) sha512sum "$file" | awk '{print $1}' ;;
        *) echo "Unknown algorithm: $algo" >&2; return 1 ;;
    esac
}

# Generate all hash types for a file, skipping unchanged ones
generate_all_hashes_if_needed() {
    local file=$1
    for algo in md5 sha1 sha256 sha512; do
        local suffix="$algo"
        local hashfile="${file}.${suffix}"
        local newhash
        newhash=$(compute_hash "$file" "$algo")
        if [[ -f "$hashfile" ]]; then
            oldhash=$(cat "$hashfile")
            if [[ "$oldhash" == "$newhash" ]]; then
                # no change
                continue
            fi
        fi
        echo "$newhash" > "$hashfile"
        echo "Written hash: $hashfile"
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

# Generate maven-metadata-local.xml in artifact folder
generate_metadata_xml() {
    local artifact_dir=$1

    # Find version directories under artifact_dir
    version_dirs=()
    while IFS= read -r -d '' dir; do
        # Only directories that are direct children
        version_dirs+=("$(basename "$dir")")
    done < <(find "$artifact_dir" -mindepth 1 -maxdepth 1 -type d -print0)

    if [[ ${#version_dirs[@]} -eq 0 ]]; then
        # nothing to do
        return
    fi

    # Sort versions lexically
    IFS=$'\n' sorted_versions=($(sort <<<"${version_dirs[*]}"))
    latest_version="${sorted_versions[-1]}"

    # Determine groupId, artifactId
    # artifact_dir like ./com/viaversion/viabackwards
    rel_path="${artifact_dir#./}"
    group_path=$(dirname "$rel_path")  # e.g. com/viaversion
    artifactId=$(basename "$artifact_dir")
    groupId=${group_path//\//.}

    # Timestamp in UTC
    timestamp=$(date -u +"%Y%m%d%H%M%S")

    metadata_path="$artifact_dir/maven-metadata-local.xml"

    cat > "$metadata_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<metadata>
  <groupId>${groupId}</groupId>
  <artifactId>${artifactId}</artifactId>
  <versioning>
    <release>${latest_version}</release>
    <versions>
EOF

    for v in "${sorted_versions[@]}"; do
        echo "      <version>${v}</version>" >> "$metadata_path"
    done

    cat >> "$metadata_path" <<EOF
    </versions>
    <lastUpdated>${timestamp}</lastUpdated>
  </versioning>
</metadata>
EOF

    echo "Generated maven-metadata-local.xml: $metadata_path"
}

# MAIN

declare -A artifact_dirs=()

while read -r jar_path; do
    echo "Processing: $jar_path"

    dir_path=$(dirname "$jar_path")
    filename=$(basename "$jar_path")
    base_name="${filename%.jar}"

    version=$(basename "$dir_path")
    artifactId=$(basename "$(dirname "$dir_path")")
    artifact_dir="$(dirname "$dir_path")"

    artifact_dirs["$artifact_dir"]=1

    rel_path="${dir_path#./}"
    group_path=$(dirname "$(dirname "$rel_path")")
    groupId=${group_path//\//.}

    pom_file="${artifactId}-${version}.pom"
    repo_file="_remote.repositories"

    full_pom_path="$dir_path/$pom_file"
    full_repo_path="$dir_path/$repo_file"

    generate_all_hashes_if_needed "$jar_path"
    generate_pom "$full_pom_path" "$groupId" "$artifactId" "$version"
    echo "Generated or updated POM: $full_pom_path"
    generate_all_hashes_if_needed "$full_pom_path"
    generate_remote_repositories "$full_repo_path" "$filename" "$pom_file"
    echo "Generated _remote.repositories: $full_repo_path"
done < <(find . -type f -name "*.jar")

for artifact_dir in "${!artifact_dirs[@]}"; do
    generate_metadata_xml "$artifact_dir"
done

