FROM postgres:18

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        git \
        postgresql-server-dev-18 \
        wget \
    ; \
    git clone https://github.com/citusdata/pg_cron.git /tmp/pg_cron; \
    cd /tmp/pg_cron; \
    make; \
    make install; \
    cd /; \
    rm -rf /tmp/pg_cron; \
    apt-get purge -y \
        build-essential \
        git \
        wget \
    ; \
    apt-get autoremove -y; \
    rm -rf /var/lib/apt/lists/*