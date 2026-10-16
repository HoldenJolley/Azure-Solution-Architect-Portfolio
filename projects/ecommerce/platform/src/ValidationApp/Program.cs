using Azure.Identity;
using Azure.Messaging.ServiceBus;
using Azure.Monitor.OpenTelemetry.AspNetCore;
using Ecommerce.ValidationApp;
using Microsoft.Azure.Cosmos;
using System.Net;
using System.Security.Cryptography;
using System.Text;

var builder = WebApplication.CreateBuilder(args);
var settings = ValidationSettings.Load();

builder.Services.AddSingleton(settings);
builder.Services.AddSingleton(_ => new DefaultAzureCredential());
builder.Services.AddSingleton(sp =>
{
    var credential = sp.GetRequiredService<DefaultAzureCredential>();
    return new CosmosClient(
        settings.CosmosEndpoint,
        credential,
        new CosmosClientOptions
        {
            ApplicationName = $"ecommerce-validation-{settings.Component}",
            ConnectionMode = ConnectionMode.Gateway
        });
});
builder.Services.AddSingleton(sp =>
{
    var credential = sp.GetRequiredService<DefaultAzureCredential>();
    return new ServiceBusClient(settings.ServiceBusNamespace, credential);
});

if (!string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("APPLICATIONINSIGHTS_CONNECTION_STRING")))
{
    builder.Services.AddOpenTelemetry().UseAzureMonitor();
}

if (!settings.IsApi)
{
    builder.Services.AddHostedService<ValidationWorker>();
}

var app = builder.Build();

app.MapGet("/health", () => Results.Ok(new
{
    status = "ok",
    component = settings.Component,
    workerRole = settings.WorkerRole,
    region = settings.Region,
    utc = DateTimeOffset.UtcNow
}));

app.MapGet("/ready", async (CosmosClient cosmos, CancellationToken cancellationToken) =>
{
    try
    {
        using var response = await cosmos
            .GetDatabase(settings.CosmosDatabase)
            .ReadStreamAsync(cancellationToken: cancellationToken);

        return response.IsSuccessStatusCode
            ? Results.Ok(new { status = "ready", dependency = "cosmos", utc = DateTimeOffset.UtcNow })
            : Results.Problem(statusCode: StatusCodes.Status503ServiceUnavailable, title: "Cosmos readiness check failed");
    }
    catch (Exception ex)
    {
        app.Logger.LogWarning(ex, "Readiness dependency check failed.");
        return Results.Problem(statusCode: StatusCodes.Status503ServiceUnavailable, title: "Dependency readiness check failed");
    }
});

if (settings.IsApi && settings.EnableValidationEndpoints)
{
    app.MapPost("/validation/run", async (
        HttpRequest request,
        CosmosClient cosmos,
        ServiceBusClient serviceBus,
        CancellationToken cancellationToken) =>
    {
        if (!IsAuthorized(request, settings.ValidationToken))
        {
            return Results.Unauthorized();
        }

        var eventId = Guid.NewGuid().ToString("D");
        var now = DateTimeOffset.UtcNow;
        var container = cosmos.GetContainer(settings.CosmosDatabase, ValidationSettings.ValidationContainerName);

        var transientProbe = new ValidationReceipt
        {
            id = $"{eventId}:api-validation",
            consumer = "api-validation",
            eventId = eventId,
            status = "transient-write-read-delete",
            processedUtc = now,
            component = settings.Component,
            region = settings.Region
        };

        await container.CreateItemAsync(
            transientProbe,
            new PartitionKey(transientProbe.consumer),
            cancellationToken: cancellationToken);

        _ = await container.ReadItemAsync<ValidationReceipt>(
            transientProbe.id,
            new PartitionKey(transientProbe.consumer),
            cancellationToken: cancellationToken);

        await container.DeleteItemAsync<ValidationReceipt>(
            transientProbe.id,
            new PartitionKey(transientProbe.consumer),
            cancellationToken: cancellationToken);

        var envelope = new ValidationEventEnvelope
        {
            eventId = eventId,
            occurredUtc = now,
            correlationId = eventId,
            orderId = $"validation-{eventId}",
            payload = new
            {
                synthetic = true,
                purpose = "portfolio-live-validation",
                source = settings.Component
            }
        };

        var message = new ServiceBusMessage(BinaryData.FromObjectAsJson(envelope))
        {
            MessageId = eventId,
            CorrelationId = eventId,
            Subject = envelope.eventType,
            ContentType = "application/json"
        };
        message.ApplicationProperties["validation"] = true;

        await using var sender = serviceBus.CreateSender(ValidationSettings.TopicName);
        await sender.SendMessageAsync(message, cancellationToken);

        app.Logger.LogInformation(
            "Synthetic validation event published. EventId={EventId} Region={Region}",
            eventId,
            settings.Region);

        return Results.Accepted($"/validation/status/{eventId}", new
        {
            eventId,
            correlationId = eventId,
            cosmosWriteReadDelete = "succeeded",
            serviceBusPublish = "succeeded",
            expectedConsumers = new[] { "inventory", "payment", "shipping", "analytics" }
        });
    });

    app.MapGet("/validation/status/{eventId}", async (
        string eventId,
        HttpRequest request,
        CosmosClient cosmos,
        CancellationToken cancellationToken) =>
    {
        if (!IsAuthorized(request, settings.ValidationToken))
        {
            return Results.Unauthorized();
        }

        var container = cosmos.GetContainer(settings.CosmosDatabase, ValidationSettings.ValidationContainerName);
        var query = new QueryDefinition(
            "SELECT c.id, c.consumer, c.eventId, c.status, c.processedUtc, c.component, c.region FROM c WHERE c.eventId = @eventId")
            .WithParameter("@eventId", eventId);

        var receipts = new List<ValidationReceipt>();
        using var iterator = container.GetItemQueryIterator<ValidationReceipt>(
            query,
            requestOptions: new QueryRequestOptions { MaxItemCount = 25 });

        while (iterator.HasMoreResults)
        {
            var page = await iterator.ReadNextAsync(cancellationToken);
            receipts.AddRange(page);
        }

        return Results.Ok(new
        {
            eventId,
            expectedConsumers = new[] { "inventory", "payment", "shipping", "analytics" },
            processedConsumers = receipts.Select(r => r.consumer).Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(x => x).ToArray(),
            receipts = receipts.OrderBy(r => r.consumer).ToArray()
        });
    });

    app.MapDelete("/validation/status/{eventId}", async (
        string eventId,
        HttpRequest request,
        CosmosClient cosmos,
        CancellationToken cancellationToken) =>
    {
        if (!IsAuthorized(request, settings.ValidationToken))
        {
            return Results.Unauthorized();
        }

        var container = cosmos.GetContainer(settings.CosmosDatabase, ValidationSettings.ValidationContainerName);
        var query = new QueryDefinition(
            "SELECT c.id, c.consumer, c.eventId, c.status, c.processedUtc, c.component, c.region FROM c WHERE c.eventId = @eventId")
            .WithParameter("@eventId", eventId);

        var deleted = 0;
        using var iterator = container.GetItemQueryIterator<ValidationReceipt>(query);
        while (iterator.HasMoreResults)
        {
            var page = await iterator.ReadNextAsync(cancellationToken);
            foreach (var receipt in page)
            {
                try
                {
                    await container.DeleteItemAsync<ValidationReceipt>(
                        receipt.id,
                        new PartitionKey(receipt.consumer),
                        cancellationToken: cancellationToken);
                    deleted++;
                }
                catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
                {
                    // Idempotent cleanup: another caller or retry already removed it.
                }
            }
        }

        return Results.Ok(new { eventId, deleted });
    });
}

app.Run();

static bool IsAuthorized(HttpRequest request, string expectedToken)
{
    if (string.IsNullOrEmpty(expectedToken))
    {
        return false;
    }

    var suppliedToken = request.Headers["X-Validation-Token"].FirstOrDefault();
    if (string.IsNullOrEmpty(suppliedToken))
    {
        return false;
    }

    var expectedBytes = Encoding.UTF8.GetBytes(expectedToken);
    var suppliedBytes = Encoding.UTF8.GetBytes(suppliedToken);

    return expectedBytes.Length == suppliedBytes.Length &&
           CryptographicOperations.FixedTimeEquals(expectedBytes, suppliedBytes);
}
