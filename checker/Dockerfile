FROM python:3.11

RUN useradd -ms /bin/bash -u 1000 checker

RUN apt update -y

USER checker
WORKDIR /checker

COPY pyproject.toml poetry.lock .

RUN pip install poetry
RUN python -m poetry install

COPY . .

ENTRYPOINT [ "python", "-m", "poetry", "run", "gunicorn", "-c", "./gunicorn.conf.py", "checker:app" ]
