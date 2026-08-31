# Non serve oggi (partiamo con Python nativo su Windows), ma vive nel repo dal
# primo commit: il giorno in cui vorrai spostare il server su un NAS o su un
# altro PC, non ci sara' niente da riscrivere.
FROM python:3.12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ffmpeg \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /srv

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

ENV MUSIC_DIR=/music \
    DATA_DIR=/data \
    HOST=0.0.0.0 \
    PORT=8080
EXPOSE 8080
VOLUME ["/data"]

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
