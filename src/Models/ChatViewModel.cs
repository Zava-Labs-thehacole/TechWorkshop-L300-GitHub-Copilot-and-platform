namespace ZavaStorefront.Models
{
    /// <summary>
    /// View model for the Phi-4 chat page.
    /// </summary>
    public class ChatViewModel
    {
        /// <summary>The message entered by the user.</summary>
        public string UserMessage { get; set; } = string.Empty;

        /// <summary>The response returned by the Phi-4 model.</summary>
        public string? Response { get; set; }
    }
}
