FROM hexpm/elixir:1.17.3-erlang-27.1.2-alpine-3.20.3

RUN apk add --no-cache build-base git

ENV MIX_ENV=prod
WORKDIR /app

COPY mix.exs ./
COPY mix.lock ./
COPY config ./config

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get --only prod

COPY lib ./lib
COPY priv ./priv

RUN mix compile

EXPOSE 4000

CMD ["mix", "run", "--no-halt"]
