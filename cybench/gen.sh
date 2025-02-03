#!/usr/bin/env bash

source .env

if [ -z "$CVE_BENCHMARK_PATH" ]; then
    echo "Set CVE_BENCHMARK_PATH in .env"
    exit 1
fi

repo_path=$CVE_BENCHMARK_PATH

cur_dir=$(pwd)
cve_list=$(cat $repo_path/standardized_cves.txt)

rm task_list.txt subtask_list.txt

for cve in $cve_list; do
    cd $cur_dir

    bench=ours/CVE/CVE-2024
    task=benchmark/$bench/$cve

    echo "$task" | tee -a task_list.txt subtask_list.txt

    mkdir -p $task/metadata/solution
    cd $task

    echo "#!/usr/bin/env bash" > init_script.sh
    chmod +x init_script.sh

    echo "
#! /usr/bin/env bash
set -ex
cd \$CVE_BENCHMARK_PATH
./run.sh target $cve 
" > start_docker.sh
    chmod +x start_docker.sh

    echo "
#! /usr/bin/env bash
set -e
cd \$CVE_BENCHMARK_PATH
./run.sh cleanup $cve
" > stop_docker.sh
    chmod +x stop_docker.sh

    # todo: solution

    if [ ! -f metadata/metadata.json ]; then
        CVE_BENCHMARK_PATH=$repo_path ./start_docker.sh
        easy_prompt=$(cd $repo_path && ./run.sh prompt $cve one_day | sed 's/localhost/target-container/g' | jq -Rsa .)
        hard_prompt=$(cd $repo_path && ./run.sh prompt $cve zero_day | sed 's/localhost/target-container/g' | jq -Rsa .)
        CVE_BENCHMARK_PATH=$repo_path ./stop_docker.sh

        cd metadata

        echo "
{
    \"categories\": [\"web\"],
    \"difficulty\": \"0\",
    \"easy_prompt\": $easy_prompt,
    \"hard_prompt\": $hard_prompt,
    \"target_host\": \"target-container:9090\",
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
" > metadata.json
    fi

    echo "#!/usr/bin/env bash" > requirements.sh
    chmod +x requirements.sh
done
