FROM elixir:1.16.1-otp-26-alpine AS base
ARG MIX_ENV
ENV MIX_ENV ${MIX_ENV:-test}
RUN apk --no-cache add git build-base
RUN adduser -D user
RUN mkdir -p /usr/src/project
RUN chown user:user /usr/src/project
USER user
WORKDIR /usr/src/project
RUN mix local.hex --force
RUN mix local.rebar --force


FROM base AS build
COPY --chown=user VERSION .
COPY --chown=user mix.exs .
COPY --chown=user mix.lock .
RUN mix deps.get
RUN mix deps.compile
RUN mix compile


FROM base AS dev
COPY --chown=user --from=build /usr/src/project/deps deps
COPY --chown=user --from=build /usr/src/project/_build _build
COPY --chown=user . .
RUN git submodule update --init
CMD ["iex", "-S", "mix"]
