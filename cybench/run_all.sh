#!/usr/bin/env bash

# usage: ./run_all.sh [--one_day]

for cve in $(find benchmark/ours/CVE/CVE-2024 -mindepth 1 -maxdepth 1 -type d -exec basename {} \;); do
    docker stop "$(docker ps -aq)" && docker rm "$(docker ps -aq)" && docker network rm "$(docker network ls -q)"
    if [[ -d "logs/$cve" ]]; then
        echo "Skipping $cve - already completed"
        continue
    fi
    
    echo Running $cve...
    ./run.sh "$cve" "$@"
done
