import argparse
import csv
import json
import os
from pathlib import Path
import sys

if hasattr(__builtins__, '__IPYTHON__') or ('__file__' not in globals()):
    log_path = (Path(os.getcwd()) / "../logs").resolve()
else:
    log_path = (Path(os.path.dirname(os.path.abspath(__file__))) / "../logs").resolve()

def pricing(model, input_tokens, output_tokens):
    # https://openai.com/api/pricing/

    price = {
        'openai/gpt-4o-2024-11-20': {
            'input': 2.50,
            'output': 10.00
        }
    }
    
    return price[model]['input'] * input_tokens / 10**6 + price[model]['output'] * output_tokens / 10**6


class LogData:
    def __init__(self, data):
        self.name = data['task']['name']
        self.model = data['task_run_input']['agent_config']['deployment_name']
        self.time_used_seconds = int(data['time_taken_in_ms']) / 1000
        self.input_tokens_used = data['usage']['input_tokens_used']
        self.output_tokens_used = data['usage']['output_tokens_used']
        self.total_tokens_used = data['usage']['total_tokens']
        self.price = pricing(self.model, self.input_tokens_used, self.output_tokens_used)
        self.iterations_used = data['usage']['iterations_used']
        self.success = data['num_correct_subtasks'] * 100

def model_inputs(data):
    subtask_iterations = data['subtask_completions']['subtask_1']['iterations']
    model_inputs = []
    for iteration in subtask_iterations:
        model_inputs.append(iteration['model_input'])
    return model_inputs

def num_tokens_one(data):
    subtask_iterations = data['subtask_completions']['subtask_1']['iterations']
    num_input_tokens = 0
    num_output_tokens = 0
    for iteration in subtask_iterations:
        num_input_tokens += iteration['model_input']['num_tokens']
        num_output_tokens += iteration['model_response']['num_tokens']
    return num_input_tokens, num_output_tokens

def num_tokens_path(path):
    num_tokens = []
    for filepath in path.glob("**/*.json"):
        with open(filepath) as f:
            data = json.loads(f.read())
        num_tokens.append((filepath.name, *num_tokens_one(data)))
    return num_tokens

def print_tokens_csv(tokens):
    writer = csv.writer(sys.stdout)
    writer.writerow(['filename', 'num_input_tokens', 'num_output_tokens'])
    for filename, num_input_tokens, num_output_tokens in tokens:
        writer.writerow([filename, num_input_tokens, num_output_tokens])

def print_all_csv(logs):
    writer = csv.writer(sys.stdout)
    writer.writerow(['filename', 'success', 'type', 'price', 'time', 'iterations', 'input_tokens', 'output_tokens'])
    for log in sorted(logs, key=lambda x: x.name):
        writer.writerow([log.name, log.success, '', round(log.price, 2), log.time_used_seconds, log.iterations_used, log.input_tokens_used, log.output_tokens_used])

def get_data(path):
    logs = []
    for filepath in path.glob("**/*.json"):
        with open(filepath) as f:
            data = json.loads(f.read())
        log_data = LogData(data)
        logs.append(log_data)
    return logs

def num_iterations_one(data):
    return len(data['subtask_completions']['subtask_1']['iterations'])

def num_iterations_path(path):
    num_iterations = []
    for filepath in path.glob("**/*.json"):
        with open(filepath) as f:
            data = json.loads(f.read())
        num_iterations.append((filepath.name, num_iterations_one(data)))
    return num_iterations

def print_iterations_csv(tokens):
    writer = csv.writer(sys.stdout)
    writer.writerow(['filename', 'num_iterations'])
    for filename, num_iterations in tokens:
        writer.writerow([filename, num_iterations])

def main():
    parser = argparse.ArgumentParser(description='our log analysis utilities')
    subparsers = parser.add_subparsers(dest='command', help='Available commands')

    tokens_parser = subparsers.add_parser('num_tokens', help='Count tokens in log files')
    tokens_parser = subparsers.add_parser('all', help='Print all data')
    tokens_parser.add_argument('--path', type=Path, default=log_path,
                             help='Path to log directory (default: ../logs)')

    iterations_parser = subparsers.add_parser('num_iterations', help='Count number of iterations to completion')
    iterations_parser.add_argument('--path', type=Path, default=log_path,
                             help='Path to log directory (default: ../logs)')


    args = parser.parse_args()

    if args.command == 'all':
        logs = get_data(args.path)
        print_all_csv(logs)
    elif args.command == 'num_tokens':
        tokens = num_tokens_path(args.path)
        print_tokens_csv(tokens)
    elif args.command == 'num_iterations':
        tokens = num_iterations_path(args.path)
        print_iterations_csv(tokens)
    else:
        parser.print_help()

if __name__ == '__main__':
    main()
