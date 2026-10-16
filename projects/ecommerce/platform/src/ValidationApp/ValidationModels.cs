namespace Ecommerce.ValidationApp;

internal sealed class ValidationEventEnvelope
{
    public required string eventId { get; init; }
    public string eventType { get; init; } = "ValidationProbe";
    public int eventVersion { get; init; } = 1;
    public required DateTimeOffset occurredUtc { get; init; }
    public required string correlationId { get; init; }
    public required string orderId { get; init; }
    public object payload { get; init; } = new { synthetic = true };
}

internal sealed class ValidationReceipt
{
    public required string id { get; init; }
    public required string consumer { get; init; }
    public required string eventId { get; init; }
    public required string status { get; init; }
    public required DateTimeOffset processedUtc { get; init; }
    public required string component { get; init; }
    public required string region { get; init; }
}
