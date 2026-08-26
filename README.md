# Banking App

## Local Configuration

Copy `.env.example` to `.env` in the repository root and adjust local values as needed.

Required values:

- `CONNECTIONSTRINGS__DEFAULTCONNECTION`
- `JWT__ISSUER`
- `JWT__AUDIENCE`
- `JWT__KEY`
- `JWT__EXPIRATIONMINUTES`
- `JWT__REFRESHTOKENEXPIRATIONDAYS`
- `CORS__ALLOWEDORIGINS__0`
- `MSSQL_SA_PASSWORD`
- `RABBITMQ_DEFAULT_USER`
- `RABBITMQ_DEFAULT_PASS`

Run infrastructure services:

```bash
docker compose up -d
```

Run the backend:

```bash
dotnet run --project backend/BankingApp.Api
```

## Demo credentials

Mobile Customer 1:

```text
Email: mobile@bankingapp.local
Password: test
```

Mobile Customer 2:

```text
Email: recipient@bankingapp.local
Password: test
```

Desktop Admin:

```text
Email: admin@bankingapp.local
Password: test
```

These are the initial credentials for a clean/seed database. If Forgot
Password is demonstrated, the selected seed account password becomes the new
password entered during the reset flow. Subsequent login must use the seed
email above together with that new password.

## Forgot Password demo

This is a Development/Demo flow intended for the seminar presentation. Keep
`DemoAuth` disabled in a real Production environment.

Before starting the API, configure a real SMTP account locally in `.env`. Do
not commit SMTP credentials. The SMTP host, port, username, password, verified
sender address, and SSL/TLS mode must come from the chosen SMTP provider.

Mobile flow:

1. Build the Mobile app with `DEMO_AUTH_ENABLED=true` and open **Forgot
   Password**.
2. Enter the real email address where the reset code should be delivered.
3. Copy the received code into **Reset Password**, then enter and confirm a new
   password.
4. Log in with `mobile@bankingapp.local` and the new password.

Desktop flow:

1. Build the Desktop app with `DEMO_AUTH_ENABLED=true` and open **Forgot
   Password**.
2. Enter the real email address where the reset code should be delivered.
3. Copy the received code into **Reset Password**, then enter and confirm a new
   password.
4. Log in with `admin@bankingapp.local` and the new password.

The entered address is used only for delivery. Mobile always resets the
configured Customer seed account, while Desktop always resets the configured
Admin seed account.

Example local `.env` shape (replace every SMTP placeholder with values from
your provider):

```dotenv
ASPNETCORE_ENVIRONMENT=Development

DEMOAUTH__ENABLED=true
DEMOAUTH__CUSTOMERACCOUNTEMAIL=mobile@bankingapp.local
DEMOAUTH__ADMINACCOUNTEMAIL=admin@bankingapp.local

EMAIL__PROVIDER=Smtp
EMAIL__SMTPHOST=<smtp-host-from-provider>
EMAIL__SMTPPORT=<smtp-port-from-provider>
EMAIL__SMTPUSERNAME=<smtp-username-from-provider>
EMAIL__SMTPPASSWORD=<smtp-password-or-app-password-from-provider>
EMAIL__FROMADDRESS=<verified-sender-address>
EMAIL__FROMNAME=Digital Banking
EMAIL__USESSL=<true-or-false-as-required-by-provider>
```

For a normal Production deployment use `DEMOAUTH__ENABLED=false`. The API
intentionally refuses to start when DemoAuth is enabled in the Production
environment.
