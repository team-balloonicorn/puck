# Puck 🧚

A magical Gleam web application for organising a birthday party.

```sh
gleam run server  # Run the server
gleam test        # Run the tests
flyctl deploy     # Deploy
```

## Environment variables

### Meta
- `ENVIRONMENT`: `development` or `production`. Used for crash reports.
- `RELOAD_TEMPLATES`: Templates are reloaded on each rendering if this it set,
  to avoid having to restart the server when making HTML changes in development.

### Registration
- `ATTEND_SECRET`: Secret route for sign up.

### Google sheets
- `SPREADSHEET_ID`: The Google sheets speadsheet to write to.
- `CLIENT_ID`: GCP oauth2 client id.
- `CLIENT_SECRET`: GCP oauth2 client secret.
- `REFRESH_TOKEN`: GCP oauth2 refresh token. See `bin/gcp-oauth-dance` for help
  generating one.

Be sure to put the GCP application into production mode to ensure refresh tokens
do not expire. Application verification is not required.

It is advised to authenticate as a user who has access to only these
spreadsheets, for security.

### Payments
- `PAYMENT_SECRET`: Secret used to authenticate incoming payment webhooks.
- `ACCOUNT_NAME`: Name on the account.
- `ACCOUNT_NUMBER`: Bank account number.
- `SORT_CODE`: Bank account sort code.

### Email config
- `SMTP_HOST`: Relay hostname.
- `SMTP_USERNAME`: Relay auth username.
- `SMTP_PASSWORD`: Relay auth password.
- `SMTP_PORT`: Relay port.
- `SMTP_FROM_EMAIL`: Email to use in the "from" field for sent emails.
- `SMTP_FROM_NAME`: Name to use in the "from" field for sent emails.
