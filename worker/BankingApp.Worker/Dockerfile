FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY backend/BankingApp.Domain/BankingApp.Domain.csproj backend/BankingApp.Domain/
COPY backend/BankingApp.Application/BankingApp.Application.csproj backend/BankingApp.Application/
COPY backend/BankingApp.Infrastructure/BankingApp.Infrastructure.csproj backend/BankingApp.Infrastructure/
COPY worker/BankingApp.Worker/BankingApp.Worker.csproj worker/BankingApp.Worker/
RUN dotnet restore worker/BankingApp.Worker/BankingApp.Worker.csproj

COPY backend/BankingApp.Domain/ backend/BankingApp.Domain/
COPY backend/BankingApp.Application/ backend/BankingApp.Application/
COPY backend/BankingApp.Infrastructure/ backend/BankingApp.Infrastructure/
COPY worker/BankingApp.Worker/ worker/BankingApp.Worker/
RUN dotnet publish worker/BankingApp.Worker/BankingApp.Worker.csproj \
    --configuration Release \
    --no-restore \
    --output /app/publish \
    /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/runtime:9.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "BankingApp.Worker.dll"]
