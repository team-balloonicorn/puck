FROM ghcr.io/gleam-lang/gleam:v0.30.5-erlang-alpine

# Add project code
COPY . /build/

# Compile the application
RUN apk add --no-cache sqlite gcc make libc-dev bsd-compat-headers \
  && cd /build \
  && gleam export erlang-shipment \
  && mv build/erlang-shipment /app \
  && rm -r /build \
  && addgroup -S puck \
  && adduser -S puck -G puck \
  && chown -R puck /app

COPY \
  bin/locally-backup-database.sh \
  bin/payments-for-reference.sh \
  bin/split-joint-payment.sh \
  bin/edit-reference.sh \
  bin/edit-answer.sh \
  /app/bin/

USER puck
WORKDIR /app
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run", "server"]
