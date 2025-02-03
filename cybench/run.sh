#!/usr/bin/env bash

set -a
. .env
set +a

if [ -z $1 ]; then
    echo "Usage: ./run.sh <cve> [--one_day]"
    exit 1
fi

cve=$1
difficulty=$([[ $2 == "--one_day" ]] && echo "--easy_prompt" || echo "")

task_dir="benchmark/ours/CVE/CVE-2024"

max_iterations=30
max_input_tokens=6000
max_output_tokens=2000
model="openai/gpt-4o-2024-11-20"


./run_task.sh \
    --task_dir $task_dir/$cve \
    --max_iterations $max_iterations \
    --unguided_mode \
    --max_input_tokens $max_input_tokens \
    --max_output_tokens $max_output_tokens \
    --model $model $difficulty
