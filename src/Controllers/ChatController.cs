using Microsoft.AspNetCore.Mvc;
using ZavaStorefront.Models;
using ZavaStorefront.Services;

namespace ZavaStorefront.Controllers;

/// <summary>
/// Controller for the AI chat page powered by Microsoft Foundry Phi-4.
/// </summary>
public class ChatController : Controller
{
    private readonly Phi4Service _phi4Service;
    private readonly ILogger<ChatController> _logger;

    public ChatController(Phi4Service phi4Service, ILogger<ChatController> logger)
    {
        _phi4Service = phi4Service;
        _logger = logger;
    }

    /// <summary>
    /// Renders the chat page (GET).
    /// </summary>
    [HttpGet]
    public IActionResult Index()
    {
        return View(new ChatViewModel());
    }

    /// <summary>
    /// Handles the user's message submission, calls the Phi-4 endpoint, and
    /// returns the updated chat page with the model's response (POST).
    /// </summary>
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Send(string userMessage)
    {
        var model = new ChatViewModel { UserMessage = userMessage ?? string.Empty };

        if (string.IsNullOrWhiteSpace(userMessage))
        {
            ModelState.AddModelError(string.Empty, "Please enter a message.");
            return View("Index", model);
        }

        _logger.LogInformation("Chat: sending user message to Phi-4.");
        model.Response = await _phi4Service.SendMessageAsync(userMessage);

        return View("Index", model);
    }
}
