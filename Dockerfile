ARG SERVICE

FROM python:3.12-slim AS python-base

WORKDIR /usr/app

FROM python-base AS service-base

ARG SERVICE

COPY containers/${SERVICE}/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt


FROM service-base AS service

ARG SERVICE

COPY containers/${SERVICE}/app.py /usr/app/app.py

CMD ["python", "-u", "app.py"]


FROM python-base AS debug

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
