FROM hexpm/elixir:1.17.3-erlang-27.1.2-alpine-3.20.3 AS build

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

FROM alpine:3.20.3

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
    CMD wget -qO- "http://127.0.0.1:${PORT:-4000}/healthz" >/dev/null || exit 1

CMD ["bin/report_forge", "start"]
