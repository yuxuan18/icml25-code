#!/bin/bash

set -e

if [[ $# -lt 2 ]]; then
	cat <<EOF
Usage:
./run_task.sh \\
	--cve <cve> \\
	--max_iterations <number> \\
	--iterations_until_hint <number> \\
	--model <model> \\
	[--easy_prompt] [--benchmark_id <id>] [--interactive_mode]
EOF
	exit 1
fi

container_name="autogpt"
image_name="autogpt"


get_cve() {
	for arg in "$@"; do
		if [[ ${arg} == "--cve" ]]; then
			echo "${2}"
		fi
	done
}

cve=$(get_cve "$@")

stop_containers() {
	echo "Stopping container..."
	(cd $CVE_BENCHMARK_PATH && ./run.sh cleanup $cve)
}

trap 'stop_containers' EXIT

# if the task has a start_docker.sh, execute it
echo "Starting container..."
(cd $CVE_BENCHMARK_PATH && ./run.sh target $cve)

# create prompts

one_day_prompt=$(cd $CVE_BENCHMARK_PATH && ./run.sh prompt-from-docker $cve one_day)
zero_day_prompt=$(cd $CVE_BENCHMARK_PATH && ./run.sh prompt-from-docker $cve zero_day)

mkdir -p classic/original_autogpt/prompts-oneday classic/original_autogpt/prompts-zeroday

echo "$one_day_prompt" > classic/original_autogpt/prompts-oneday/${cve}-prompt.txt
echo "$zero_day_prompt" > classic/original_autogpt/prompts-zeroday/${cve}-prompt.txt

# build agent

docker build . -f Dockerfile -t "${image_name}"

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
	--network "${network_name}" \
	-v /.venv:/app/.venv \
	-v /.cache:/root/.cache \
    -e CVE=$cve \
	"${image_name}" | tee /tmp/benchmark-latest.log

# Get exit status of `docker run`
exit_status=${PIPESTATUS[0]}

docker cp "${container_name}:/app/classic/original_autogpt/environment/." "$(pwd)/logs/"

docker rm -f "${container_name}"

stop_containers

if [[ ${exit_status} -ne 0 ]]; then
	echo "Error: Task failed."
	exit 1
fi
