#!/bin/bash
# TO EXECUTE USE COMMAND: ./z_tree.sh

# Output file
output_file="z_output.txt"

# Files to exclude
exclude_files=(z_tree.sh, z_output.txt, requirements.txt, README.md)

# Folders to exclude
exclude_folders=(node_modules, .git, **pycache**, instance)

# File types to exclude
exclude_types=(.db)

# Max file size to include (in bytes)
max_file_size=$((10 * 1024 * 1024))  # 10 MB

# Option to exclude binary files (set to "yes" or "no")
exclude_binary="yes"

# Option to exclude empty files (set to "yes" or "no")
exclude_empty="yes"

# Number of days to exclude files before (set to 0 to disable)
exclude_before_days=0

# Number of days to exclude files after (set to 0 to disable)
exclude_after_days=0

# Function to check if a file is likely binary
is_binary() {
    if [[ "$exclude_binary" == "yes" ]]; then
        file -b --mime-encoding "$1" | grep -qv "utf-\|ascii\|us-ascii"
    else
        return 1  # Always return false if exclude_binary is not "yes"
    fi
}

# Function to check if a file is empty
is_empty() {
    if [[ "$exclude_empty" == "yes" ]]; then
        [[ ! -s "$1" ]]
    else
        return 1  # Always return false if exclude_empty is not "yes"
    fi
}

# Function to check if a file is within the specified date range
is_within_date_range() {
    local file="$1"
    local file_time=$(stat -c %Y "$file")
    local current_time=$(date +%s)

    if [[ $exclude_before_days -gt 0 ]]; then
        local before_time=$((current_time - exclude_before_days * 86400))
        [[ $file_time -lt $before_time ]] && return 1
    fi

    if [[ $exclude_after_days -gt 0 ]]; then
        local after_time=$((current_time - exclude_after_days * 86400))
        [[ $file_time -gt $after_time ]] && return 1
    fi

    return 0
}

show_tree() {
    local dir="$1"
    local indent="$2"
    for item in "$dir"/*; do
        if [[ -d "$item" ]]; then
            # Check if the folder should be excluded
            local exclude=false
            for exclude_folder in ${exclude_folders[@]//,/ }; do
                if [[ "$(basename "$item")" == "$exclude_folder" ]]; then
                    exclude=true
                    break
                fi
            done
            if ! $exclude; then
                echo "${indent}$(basename "$item")/" >> "$output_file"
                show_tree "$item" "  $indent"
            fi
        elif [[ -f "$item" ]]; then
            # Check various exclusion criteria
            local exclude=false
            
            # Check file name
            for exclude_file in ${exclude_files[@]//,/ }; do
                if [[ "$(basename "$item")" == "$exclude_file" ]]; then
                    exclude=true
                    break
                fi
            done
            # Check file extension
            for exclude_type in ${exclude_types[@]//,/ }; do
                if [[ "$item" == *"$exclude_type" ]]; then
                    exclude=true
                    break
                fi
            done
            # Check file size
            if [[ $(stat -c %s "$item") -gt $max_file_size ]]; then
                exclude=true
            fi
            # Check if file is binary
            if is_binary "$item"; then
                exclude=true
            fi
            # Check if file is empty
            if is_empty "$item"; then
                exclude=true
            fi
            # Check if file is within date range
            if ! is_within_date_range "$item"; then
                exclude=true
            fi
            if ! $exclude; then
                echo "${indent}$(basename "$item")" >> "$output_file"
                echo "${indent}Contents of $item:" >> "$output_file"
                cat "$item" | sed "s/^/${indent}  /" >> "$output_file"
                echo "${indent}>.end.<" >> "$output_file"
                echo >> "$output_file"
            fi
        fi
    done
}

# Clear or create the output file
> "$output_file"

# Start the tree from the current directory
show_tree "." ""

echo "Output has been written to $output_file"
