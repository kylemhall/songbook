FROM perl:latest
MAINTAINER Kyle M Hall <kyle.m.hall@gmail.com>

RUN cpanm App::Music::ChordPro
RUN apt-get update && apt-get install -y pdftk poppler-utils git htmldoc \
    && rm -rf /var/cache/apt/archives/* \
    && rm -rf /var/lib/api/lists/*

WORKDIR /app
COPY . .

CMD perl /app/compile_songbook.pl
