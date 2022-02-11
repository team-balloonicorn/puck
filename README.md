# Puck 🧚

A magical Gleam web application for organising a birthday party.

```sh
gleam run server  # Run the server
gleam test        # Run the tests
flyctl deploy     # Deploy
```

## Environment variables

- `ENVIRONMENT`: `development` or `production`. Used for crash reports.
- `SPREADSHEET_ID`: The Google sheets speadsheet to write to.
- `CLIENT_ID`: GCP oauth2 client id.
- `CLIENT_SECRET`: GCP oauth2 client secret.
- `REFRESH_TOKEN`: GCP oauth2 refresh token. See `bin/gcp-oauth-dance` for help
  generating one.

Be sure to put the GCP application into production mode to ensure refresh tokens
do not expire. Application verification is not required.
