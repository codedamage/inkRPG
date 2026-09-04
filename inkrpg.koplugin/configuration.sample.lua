-- Copy this file to configuration.lua (same folder) and fill in your key.
-- configuration.lua is gitignored -- never commit real API keys.
--
-- `provider` selects which entry under provider_settings is active. Any
-- OpenAI-compatible chat-completions endpoint works here: OpenAI itself,
-- OpenRouter, Groq, DeepSeek, or a local Ollama server started with
-- `ollama serve` (its OpenAI-compat endpoint is usually
-- http://localhost:11434/v1/chat/completions -- handy for free testing).
--
-- Native Claude/Gemini endpoints use a different request/response shape
-- and need a small dedicated handler -- not wired up yet, see PLAN.md
-- Phase 2.

return {
    provider = "openai",
    provider_settings = {
        openai = {
            model = "gpt-4o-mini",
            base_url = "https://api.openai.com/v1/chat/completions",
            api_key = "sk-your-key-here",
        },
        local_ollama = {
            model = "llama3.1",
            base_url = "http://localhost:11434/v1/chat/completions",
            api_key = "ollama", -- ignored by Ollama, but required by the request shape
        },
    },
}
