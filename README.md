# Banking App

## Local Configuration

Copy `.env.example` to `.env` in the repository root and adjust local values as needed.

Required values:

- `CONNECTIONSTRINGS__DEFAULTCONNECTION`
- `JWT__ISSUER`
- `JWT__AUDIENCE`
- `JWT__KEY`
- `JWT__EXPIRATIONMINUTES`
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
