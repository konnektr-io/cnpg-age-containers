# vim:set ft=dockerfile:
#
# Copyright The CloudNativePG Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
FROM postgres:16.8-bookworm

# Do not split the description, otherwise we will see a blank space in the labels
LABEL name="Apache AGE Container Images" \
    vendor="Konnektr.io" \
    version="${PG_VERSION}" \
    release="5" \
    summary="Apache AGE Container images." \
    description="This Docker image contains PostgreSQL, Apache Age and Barman Cloud based on Postgres 16.8-bookworm and Apache AGE 1.5.0."

LABEL org.opencontainers.image.description="This Docker image contains PostgreSQL, Apache Age and Barman Cloud based on Postgres 16.8-bookworm."

COPY requirements.txt /

# Install Apache AGE from source
# use the advice from here https://cloudnative-pg.io/blog/creating-container-images/
# but also add in the deps for, and use, the AGE repo (https://age.apache.org/getstarted/quickstart/)
RUN set -xe ;\
    apt update && apt install wget lsb-release gnupg2 -y ;\
    sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' ;\
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - ;\
    apt-get update ;\
    apt-get install -y "postgresql-server-dev-${PG_MAJOR}" build-essential git libreadline-dev zlib1g-dev flex bison flex locales; \
    cd /tmp; \
    git clone --branch release/PG16/1.5.0 https://github.com/apache/age.git; \
    cd /tmp/age; \
    PG_CONFIG=/usr/lib/postgresql/${PG_MAJOR}/bin/pg_config make; \
    PG_CONFIG=/usr/lib/postgresql/${PG_MAJOR}/bin/pg_config make install; \
    rm -fr /tmp/* ; \
    rm -rf /var/lib/apt/lists/*;

# Install default additional extensions
RUN set -xe; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    "postgresql-${PG_MAJOR}-pgaudit" \
    "postgresql-${PG_MAJOR}-pgvector" \
    "postgresql-${PG_MAJOR}-pg-failover-slots" \
    ; \
    rm -fr /tmp/* ; \
    rm -rf /var/lib/apt/lists/*;

# Install barman-cloud
RUN set -xe; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    # We require build dependencies to build snappy 0.6
    # on Python 3.11 or greater.
    # TODO: Remove build deps once barman unpins the snappy version or
    # https://github.com/EnterpriseDB/barman/issues/905 is completed
    build-essential python3-dev libsnappy-dev \
    python3-pip \
    python3-psycopg2 \
    python3-setuptools \
    ; \
    pip3 install --break-system-packages --upgrade pip; \
    # TODO: Remove --no-deps once https://github.com/pypa/pip/issues/9644 is solved
    pip3 install --break-system-packages --no-deps -r requirements.txt; \
    # We require build dependencies to build snappy 0.6
    # on Python 3.11 or greater.
    # TODO: Remove build deps once barman unpins the snappy version or
    # https://github.com/EnterpriseDB/barman/issues/905 is completed
    apt-get remove -y --purge --autoremove \
    build-essential \
    python3-dev \
    libsnappy-dev \
    ; \
    rm -rf /var/lib/apt/lists/*;

# Create the plugins directory and a symlink to allow non-superusers to load the Apache AGE library
RUN mkdir -p /usr/lib/postgresql/16/lib/plugins && ln -s /usr/lib/postgresql/16/lib/age.so /usr/lib/postgresql/16/lib/plugins/age.so

# Change the uid of postgres to 26
RUN usermod -u 26 postgres
USER 26