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
- `PUSHOVER_USER`: Pushover user to send admin notification to.
- `PUSHOVER_KEY`: Pushover API key.

### Users and authentication
- `SIGNING_SECRET`: Secret used to sign cookies.

### Registration
- `ATTEND_SECRET`: Secret route for sign up.

### Payments
- `PAYMENT_SECRET`: Secret used to authenticate incoming payment webhooks.
- `ACCOUNT_NAME`: Name on the account.
- `ACCOUNT_NUMBER`: Bank account number.
- `SORT_CODE`: Bank account sort code.

### Email config
- `ZEPTOMAIL_API_KEY`: ZeptoMail API key.
- `EMAIL_FROM_NAME`: Name for the email sender identity.
- `EMAIL_FROM_ADDRESS`: Address for the email sender identity.
- `EMAIL_REPLYTO_NAME`: Name for the email reply-to identity.
- `EMAIL_REPLYTO_ADDRESS`: Address for the email reply-to identity.
