using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace ZavaStorefront.Services
{
    /// <summary>
    /// Service for communicating with the Microsoft Foundry Phi-4 chat endpoint.
    /// Configuration is read from the "Phi4" section of appsettings.json.
    /// </summary>
    public class Phi4Service
    {
        private readonly HttpClient _httpClient;
        private readonly ILogger<Phi4Service> _logger;
        private readonly string _endpointUrl;
        private readonly string _modelName;

        public Phi4Service(HttpClient httpClient, IConfiguration configuration, ILogger<Phi4Service> logger)
        {
            _httpClient = httpClient;
            _logger = logger;

            var phi4Section = configuration.GetSection("Phi4");
            _endpointUrl = phi4Section["EndpointUrl"] ?? throw new InvalidOperationException("Phi4:EndpointUrl is not configured.");
            _modelName = phi4Section["ModelName"] ?? "Phi-4";

            var apiKey = phi4Section["ApiKey"];
            if (!string.IsNullOrWhiteSpace(apiKey))
            {
                _httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);
            }
        }

        /// <summary>
        /// Sends a user message to the Phi-4 Foundry endpoint and returns the assistant's reply.
        /// </summary>
        /// <param name="userMessage">The message text entered by the user.</param>
        /// <returns>The text response from Phi-4, or an error message string.</returns>
        public async Task<string> SendMessageAsync(string userMessage)
        {
            // Build an OpenAI-compatible chat completions request body.
            var requestBody = new
            {
                model = _modelName,
                messages = new[]
                {
                    new { role = "user", content = userMessage }
                }
            };

            var json = JsonSerializer.Serialize(requestBody);
            using (var content = new StringContent(json, Encoding.UTF8, "application/json"))
            {
                _logger.LogInformation("Sending message to Phi-4 endpoint: {Endpoint}", _endpointUrl);

                try
                {
                    var response = await _httpClient.PostAsync(_endpointUrl, content);
                    var responseBody = await response.Content.ReadAsStringAsync();

                    if (!response.IsSuccessStatusCode)
                    {
                        _logger.LogWarning("Phi-4 endpoint returned {StatusCode}: {Body}", response.StatusCode, responseBody);
                        return $"Error: The Phi-4 endpoint returned status {(int)response.StatusCode} ({response.StatusCode}).";
                    }

                    // Parse the OpenAI-compatible response to extract the assistant's reply.
                    using var doc = JsonDocument.Parse(responseBody);
                    var choices = doc.RootElement.GetProperty("choices");
                    if (choices.GetArrayLength() == 0)
                    {
                        _logger.LogWarning("Phi-4 response contained no choices.");
                        return "(no response content)";
                    }

                    var reply = choices[0]
                        .GetProperty("message")
                        .GetProperty("content")
                        .GetString();

                    return reply ?? "(no response content)";
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Failed to call Phi-4 endpoint.");
                    return $"Error: Could not reach the Phi-4 endpoint. {ex.Message}";
                }
            }
        }
    }
}
