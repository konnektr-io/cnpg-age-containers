ARG PG_MAJOR=17
ARG AGE_VERSION=1.6.0
ARG CNPG_VARIANT=standard-trixie

# Build stage: Install necessary development tools for compilation and installation
FROM postgres:${PG_MAJOR} AS build

RUN apt-get update \
    && apt-get install -y --no-install-recommends --no-install-suggests \
    bison \
    build-essential \
    flex \
    postgresql-server-dev-$PG_MAJOR

RUN git clone --branch release/PG$PG_MAJOR/$AGE_VERSION https://github.com/apache/age.git

WORKDIR /age

RUN make && make install

# Final stage: Create a final image by copying the files created in the build stage
FROM ghcr.io/cloudnative-pg/postgresql:${PG_MAJOR}-${CNPG_VARIANT}

USER root

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8

ENV LANG=en_US.UTF-8
ENV LC_COLLATE=en_US.UTF-8
ENV LC_CTYPE=en_US.UTF-8

COPY --from=build /usr/lib/postgresql/$PG_MAJOR/lib/age.so /usr/lib/postgresql/$PG_MAJOR/lib/
COPY --from=build /usr/share/postgresql/$PG_MAJOR/extension/age--$AGE_VERSION.sql /usr/share/postgresql/$PG_MAJOR/extension/
COPY --from=build /usr/share/postgresql/$PG_MAJOR/extension/age.control /usr/share/postgresql/$PG_MAJOR/extension/

# Create the plugins directory and a symlink to allow non-superusers to load the Apache AGE library
RUN mkdir -p /usr/lib/postgresql/$PG_MAJOR/lib/plugins && ln -s /usr/lib/postgresql/$PG_MAJOR/lib/age.so /usr/lib/postgresql/$PG_MAJOR/lib/plugins/age.so

USER 26