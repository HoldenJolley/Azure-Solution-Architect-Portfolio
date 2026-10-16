namespace Ecommerce.ValidationApp;

internal sealed record ValidationSettings(
    string Component,
    string WorkerRole,
    string Region,
    string CosmosEndpoint,
    string CosmosDatabase,
    string ServiceBusNamespace,
    bool EnableValidationEndpoints,
    string ValidationToken)
{
    public const string TopicName = "commerce-events";
    public const string ValidationContainerName = "processedMessages";

    public bool IsApi => string.Equals(Component, "api", StringComparison.OrdinalIgnoreCase);

    public static ValidationSettings Load()
    {
        var component = Require("APP_COMPONENT");
        var endpointsEnabled = bool.TryParse(Environment.GetEnvironmentVariable("ENABLE_VALIDATION_ENDPOINTS"), out var enabled) && enabled;
        var token = Environment.GetEnvironmentVariable("VALIDATION_TOKEN") ?? string.Empty;

        if (endpointsEnabled && string.Equals(component, "api", StringComparison.OrdinalIgnoreCase) && string.IsNullOrWhiteSpace(token))
        {
            throw new InvalidOperationException("VALIDATION_TOKEN is required when validation endpoints are enabled.");
        }

        return new ValidationSettings(
            Component: component,
            WorkerRole: Environment.GetEnvironmentVariable("WORKER_ROLE") ?? string.Empty,
            Region: Environment.GetEnvironmentVariable("REGION") ?? "unknown",
            CosmosEndpoint: Require("AZURE_COSMOS_ENDPOINT"),
            CosmosDatabase: Require("AZURE_COSMOS_DATABASE"),
            ServiceBusNamespace: Require("SERVICEBUS__fullyQualifiedNamespace"),
            EnableValidationEndpoints: endpointsEnabled,
            ValidationToken: token);
    }

    private static string Require(string name)
    {
        var value = Environment.GetEnvironmentVariable(name);
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException($"Required application setting '{name}' is missing.");
        }

        return value;
    }
}
