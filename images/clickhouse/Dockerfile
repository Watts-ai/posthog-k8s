ARG CLICKHOUSE_VERSION=26.3.9.8
FROM clickhouse/clickhouse-server:${CLICKHOUSE_VERSION}

ARG POSTHOG_COMMIT
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates && \
    git clone --no-checkout --depth 1 --filter=blob:none \
        https://github.com/PostHog/posthog.git /tmp/posthog && \
    cd /tmp/posthog && \
    git sparse-checkout set docker/clickhouse posthog/idl posthog/user_scripts && \
    git fetch --depth 1 origin ${POSTHOG_COMMIT} && \
    git checkout FETCH_HEAD && \
    cp docker/clickhouse/config.xml /etc/clickhouse-server/config.xml && \
    cp docker/clickhouse/config.d/default.xml /etc/clickhouse-server/config.d/default.xml && \
    cp docker/clickhouse/users.xml /etc/clickhouse-server/users.xml && \
    cp docker/clickhouse/user_defined_function.xml /etc/clickhouse-server/user_defined_function.xml && \
    mkdir -p /docker-entrypoint-initdb.d && \
    cp docker/clickhouse/docker-entrypoint-initdb.d/init-db.sh /docker-entrypoint-initdb.d/ && \
    cp -r posthog/idl /idl && \
    cp -r posthog/user_scripts /var/lib/clickhouse/user_scripts && \
    rm -rf /tmp/posthog && \
    apt-get remove -y git && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*
