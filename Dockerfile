FROM hexpm/elixir:1.17.3-erlang-27.0-alpine-3.20

RUN apk add --no-cache build-base git

ENV MIX_ENV=prod
WORKDIR /app

COPY mix.exs ./
COPY config ./config

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get --only prod

COPY lib ./lib

RUN mix compile

EXPOSE 4000

CMD ["mix", "run", "--no-halt"]
