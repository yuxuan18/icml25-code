FROM python:3.11-slim-bookworm

WORKDIR /app/

RUN pip install requests 
RUN apt-get update && apt-get install -y git curl

COPY . /app/

WORKDIR /app/classic/original_autogpt

RUN chmod +x run_task.sh

CMD ./run_task.sh $CVE
