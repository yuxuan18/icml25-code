#!/usr/bin/env bash

# usage: ./run_all.sh [--one_day]
for cve in CVE-2024-32986 CVE-2024-35187 CVE-2024-5314 CVE-2024-5315; do
    if [[ -d "logs/$cve" ]]; then
        echo "Skipping $cve - already completed"
        continue
    fi
    
    echo Running $cve...
    ./run.sh "$cve" "$@"
done