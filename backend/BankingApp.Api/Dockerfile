FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY backend/BankingApp.Domain/BankingApp.Domain.csproj backend/BankingApp.Domain/
COPY backend/BankingApp.Application/BankingApp.Application.csproj backend/BankingApp.Application/
COPY backend/BankingApp.Infrastructure/BankingApp.Infrastructure.csproj backend/BankingApp.Infrastructure/
COPY backend/BankingApp.Api/BankingApp.Api.csproj backend/BankingApp.Api/
RUN dotnet restore backend/BankingApp.Api/BankingApp.Api.csproj

COPY backend/BankingApp.Domain/ backend/BankingApp.Domain/
COPY backend/BankingApp.Application/ backend/BankingApp.Application/
COPY backend/BankingApp.Infrastructure/ backend/BankingApp.Infrastructure/
COPY backend/BankingApp.Api/ backend/BankingApp.Api/
RUN dotnet publish backend/BankingApp.Api/BankingApp.Api.csproj \
    --configuration Release \
    --no-restore \
    --output /app/publish \
    /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
RUN apt-get update \
    && apt-get install --yes --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app/publish .
EXPOSE 8080
ENTRYPOINT ["dotnet", "BankingApp.Api.dll"]
