using Azure.Messaging.ServiceBus;
using Microsoft.Azure.Cosmos;
using System.Net;

namespace Ecommerce.ValidationApp;

internal sealed class ValidationWorker : BackgroundService
{
    private readonly ServiceBusClient _serviceBus;
    private readonly CosmosClient _cosmos;
    private readonly ValidationSettings _settings;
    private readonly ILogger<ValidationWorker> _logger;
    private ServiceBusProcessor? _processor;

    public ValidationWorker(
        ServiceBusClient serviceBus,
        CosmosClient cosmos,
        ValidationSettings settings,
        ILogger<ValidationWorker> logger)
    {
        _serviceBus = serviceBus;
        _cosmos = cosmos;
        _settings = settings;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (string.IsNullOrWhiteSpace(_settings.WorkerRole))
        {
            throw new InvalidOperationException("WORKER_ROLE is required for validation worker processes.");
        }

        _processor = _serviceBus.CreateProcessor(
            ValidationSettings.TopicName,
            _settings.WorkerRole,
            new ServiceBusProcessorOptions
            {
                AutoCompleteMessages = false,
                MaxConcurrentCalls = 1,
                MaxAutoLockRenewalDuration = TimeSpan.FromMinutes(5)
            });

        _processor.ProcessMessageAsync += ProcessMessageAsync;
        _processor.ProcessErrorAsync += ProcessErrorAsync;

        await _processor.StartProcessingAsync(stoppingToken);
        _logger.LogInformation(
            "Validation worker started. Role={Role} Region={Region}",
            _settings.WorkerRole,
            _settings.Region);

        await Task.Delay(Timeout.InfiniteTimeSpan, stoppingToken);
    }

    private async Task ProcessMessageAsync(ProcessMessageEventArgs args)
    {
        ValidationEventEnvelope? envelope;

        try
        {
            envelope = args.Message.Body.ToObjectFromJson<ValidationEventEnvelope>();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Unable to deserialize validation message {MessageId}", args.Message.MessageId);
            await args.DeadLetterMessageAsync(args.Message, "InvalidValidationEnvelope", ex.Message);
            return;
        }

        if (envelope is null || !string.Equals(envelope.eventType, "ValidationProbe", StringComparison.Ordinal))
        {
            await args.DeadLetterMessageAsync(
                args.Message,
                "UnsupportedEventType",
                "The temporary validation workload only processes ValidationProbe events.");
            return;
        }

        var receipt = new ValidationReceipt
        {
            id = $"{envelope.eventId}:{_settings.WorkerRole}",
            consumer = _settings.WorkerRole,
            eventId = envelope.eventId,
            status = "processed",
            processedUtc = DateTimeOffset.UtcNow,
            component = _settings.Component,
            region = _settings.Region
        };

        var container = _cosmos.GetContainer(_settings.CosmosDatabase, ValidationSettings.ValidationContainerName);

        try
        {
            await container.CreateItemAsync(
                receipt,
                new PartitionKey(receipt.consumer),
                cancellationToken: args.CancellationToken);
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
        {
            _logger.LogInformation(
                "Validation receipt already exists for EventId={EventId} Consumer={Consumer}; treating delivery as idempotent.",
                receipt.eventId,
                receipt.consumer);
        }

        await args.CompleteMessageAsync(args.Message, args.CancellationToken);
        _logger.LogInformation(
            "Validation event processed. EventId={EventId} Consumer={Consumer}",
            envelope.eventId,
            _settings.WorkerRole);
    }

    private Task ProcessErrorAsync(ProcessErrorEventArgs args)
    {
        _logger.LogError(
            args.Exception,
            "Service Bus validation worker error. Entity={EntityPath} Source={ErrorSource}",
            args.EntityPath,
            args.ErrorSource);
        return Task.CompletedTask;
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        if (_processor is not null)
        {
            await _processor.StopProcessingAsync(cancellationToken);
            await _processor.DisposeAsync();
        }

        await base.StopAsync(cancellationToken);
    }
}
