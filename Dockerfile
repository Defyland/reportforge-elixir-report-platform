FROM hexpm/elixir:1.17.3-erlang-27.1.2-alpine-3.20.3@sha256:1ec24d1913fa669eb93797df02e70a021da73786ab2bbb1f0de1a6360ba90255 AS build

RUN apk add --no-cache build-base git

ENV MIX_ENV=prod
WORKDIR /app

COPY mix.exs ./
COPY mix.lock ./
COPY config ./config

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get --only prod && \
    mix deps.compile

COPY lib ./lib
COPY priv ./priv

RUN mix compile && mix release

FROM alpine:3.20.3@sha256:1e42bbe2508154c9126d48c2b8a75420c3544343bf86fd041fb7527e017a4b4a

RUN apk add --no-cache ca-certificates libstdc++ ncurses-libs openssl && \
    addgroup -S reportforge && \
    adduser -S reportforge -G reportforge

ENV HOME=/app \
    MIX_ENV=prod

WORKDIR /app

COPY --from=build --chown=reportforge:reportforge /app/_build/prod/rel/report_forge ./

USER reportforge

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget -qO- "http://127.0.0.1:${PORT:-4000}/readyz" >/dev/null || exit 1

CMD ["bin/report_forge", "start"]
