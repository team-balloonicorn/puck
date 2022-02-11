FROM ghcr.io/gleam-lang/gleam:v0.19.0-erlang-alpine

# Create a group and user to run as
RUN addgroup -S puckgroup && adduser -S puckuser -G puckgroup
USER puckuser

# Add project code
WORKDIR /app/
COPY . ./

# Compile the Gleam application
RUN gleam build && \
  cp build/packages/ranch/ebin/ranch.app build/dev/erlang/ranch/ebin/ranch.app

# Run the application
CMD ["gleam", "run", "server"]
