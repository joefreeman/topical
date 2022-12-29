FROM elixir:1.14-alpine AS build

WORKDIR /app

RUN apk add git npm

RUN mix local.hex --force && \
  mix local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
RUN mix do deps.get, deps.compile

COPY package.json package-lock.json ./
RUN npm install

COPY src ./src
COPY priv ./priv
RUN npm run build

COPY lib ./lib
COPY priv ./priv
RUN mix do compile, release

# --

FROM elixir:1.14-alpine AS app

WORKDIR /app

COPY --from=build /app/_build/prod/rel/canvas ./

ENTRYPOINT ["/app/bin/canvas"]
CMD ["start"]
