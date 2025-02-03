#!/bin/bash

set -e

if [[ -z ${DOCKER_NETWORK_DRIVER} ]]; then
	# default network is bridge
	export DOCKER_NETWORK_DRIVER="bridge"
fi

# Validate current directory for volume mounting
if [[ "$(basename "$(pwd)")" != "cybench" ]]; then
	echo "Error: Please run this script from the cybench directory."
	exit 1
fi

if [[ $# -lt 2 ]]; then
	cat <<EOF
Usage:
./run_task.sh \\
	--task_dir <path> \\
	--max_iterations <number> \\
	--iterations_until_hint <number> \\
	--model <model> \\
	[--easy_prompt] [--benchmark_id <id>] [--interactive_mode]
EOF
	exit 1
fi

container_name="cybench"
image_name="cybench/cybench:cve"

# Create shared network if it doesn't exist
# if ! docker network ls | grep -q "${network_name}"; then
# 	echo "Creating Docker network: ${network_name}"
# 	docker network create "${network_name}"
# fi

get_task_dir() {
	for arg in "$@"; do
		if [[ ${arg} == "--task_dir" ]]; then
			echo "${2}"
		fi
	done
}

task_dir=$(get_task_dir "$@")

stop_containers() {
    if [[ -f "${task_dir}/stop_docker.sh" ]]; then
	    echo "Executing stop_docker.sh script for the task"
	    "${task_dir}/stop_docker.sh"
    fi
}

trap 'stop_containers' EXIT

# if the task has a start_docker.sh, execute it
if [[ -f "${task_dir}/start_docker.sh" ]]; then
	echo "Executing start_docker.sh script for the task"
	"${task_dir}/start_docker.sh"
fi

# create metadata file

cve=$(basename "${task_dir}")

easy_prompt=$(cd $CVE_BENCHMARK_PATH && ./run.sh prompt-from-docker $cve one_day | jq -Rsa .)
hard_prompt=$(cd $CVE_BENCHMARK_PATH && ./run.sh prompt-from-docker $cve zero_day | jq -Rsa .)
target_host=$(cd $CVE_BENCHMARK_PATH && ./run.sh target-info | jq .application_url_from_docker | cut -d'/' -f1 | tr -d '"')

echo "{
    \"categories\": [\"web\"],
    \"difficulty\": \"0\",
    \"easy_prompt\": $easy_prompt,
    \"hard_prompt\": $hard_prompt,
    \"target_host\": \"$target_host\",
    \"tools\":
        {
            \"terminal\": [],
            \"gui\": [],
            \"languages\": [],
            \"other\": []
        },
    \"internet\":
        {
            \"useful\": false,
            \"necessary\": false
        },
    \"stateful_shell\": false,
    \"subtasks\":
        [
            {
                \"subtask\": \"Perform an exploit\",
                \"question\": \"\",
                \"answer\": \"\",
                \"answer_format\": \"\",
                \"hints\": [],
                \"commands\": [],
                \"solution_files\": [],
                \"context\": \"\",
                \"annotator_note\": \"\",
                \"tools\": {
                    \"terminal\": [],
                    \"gui\": [],
                    \"languages\": []
                },
                \"internet\": {
                    \"useful\": false,
                    \"necessary\": false
                },
                \"stateful_shell\": false
            }
        ]
}
" > "${task_dir}/metadata/metadata.json"

# build agent

docker build . -f Dockerfile.cve -t "${image_name}"

# Just in case an old container didn't get cleaned up completely,
# let's make sure we start from a clean slate.
docker rm -f "${container_name}" 2>/dev/null

# run agent

network_name=$(echo "${cve}" | tr '[:upper:]' '[:lower:]')_default

# Debug information to check what is being passed
echo "Running Docker container with the following command:"
echo "docker run --name ${container_name} --network ${network_name} --rm -v $(pwd)/agent:/app/agent -v $(pwd)/run_task.py:/app/run_task.py --env-file=.env ${image_name} python /app/run_task.py $@"

docker run \
	--name "${container_name}" \
	-it \
	--privileged \
	--network "${network_name}" \
	-v "$(pwd)/agent":/app/agent:ro \
	-v "$(pwd)/run_task.py":/app/run_task.py:ro \
	--env-file=.env \
	"${image_name}" "$@" | tee /tmp/benchmark-latest.log

# Get exit status of `docker run`
exit_status=${PIPESTATUS[0]}

docker cp "${container_name}:/app/logs/." "$(pwd)/logs/"

docker rm -f "${container_name}"

stop_containers

if [[ ${exit_status} -ne 0 ]]; then
	echo "Error: Task failed."
	exit 1
fi
