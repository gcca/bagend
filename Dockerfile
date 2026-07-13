# syntax=docker/dockerfile:1.7

ARG ALPINE_VERSION=3.23
ARG DEPS_IMAGE=ghcr.io/gcca/bagend-deps:latest
ARG DBMATE_IMAGE=ghcr.io/amacneil/dbmate:2.33.0

FROM ${DBMATE_IMAGE} AS dbmate
FROM ${DEPS_IMAGE} AS deps

FROM deps AS build

WORKDIR /src

COPY build.zig build.zig.zon ./
COPY 3rdparty ./3rdparty
COPY cmd ./cmd
COPY src ./src

RUN zig build -Doptimize=ReleaseFast

FROM alpine:${ALPINE_VERSION} AS execute

RUN apk add --no-cache \
    ca-certificates \
    curl \
    grpc-cpp \
    libgcc \
    libstdc++ \
    protobuf \
    sqlite \
    sqlite-libs

WORKDIR /app

COPY --from=build /src/zig-out/bin/bagend /usr/local/bin/bagend
COPY --from=dbmate /usr/local/bin/dbmate /usr/local/bin/dbmate
COPY db/migrations/*.sql /app/migrations/
COPY db/fixtures/*.sql /app/fixtures/
COPY docker-entrypoint.sh /usr/local/bin/bagend-entrypoint

RUN chmod +x /usr/local/bin/bagend-entrypoint \
    && mkdir -p /app/db

ENV TZ=UTC \
    DB_URL=/app/db/bagend.db \
    LOAD_SAMPLE_DATA=0

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -fs http://127.0.0.1:8000/bagend/healthcheck >/dev/null || exit 1

ENTRYPOINT ["bagend-entrypoint"]
