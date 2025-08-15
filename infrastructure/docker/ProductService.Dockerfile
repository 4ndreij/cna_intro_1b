# Use the official .NET runtime as base image
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080
EXPOSE 3500

# Create a non-root user for security
RUN adduser --disabled-password --gecos "" --uid 1001 appuser

# Use the SDK image for building
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src

# Copy project files first for better layer caching
COPY ["src/ProductService/ProductService.csproj", "src/ProductService/"]
COPY ["src/Shared/Shared.csproj", "src/Shared/"]

# Restore dependencies with clean cache
RUN dotnet nuget locals all --clear && \
    dotnet restore "src/ProductService/ProductService.csproj" --verbosity normal

# Copy source code
COPY . .
WORKDIR "/src/src/ProductService"

# Build the application
RUN dotnet build "ProductService.csproj" \
    -c $BUILD_CONFIGURATION \
    -o /app/build

# Publish the application
FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "ProductService.csproj" \
    -c $BUILD_CONFIGURATION \
    -o /app/publish \
    /p:UseAppHost=false

# Final image
FROM base AS final
WORKDIR /app

# Copy the published application
COPY --from=publish /app/publish .

# Set ownership and switch to non-root user
RUN chown -R appuser:appuser /app
USER appuser

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["dotnet", "ProductService.dll"]
