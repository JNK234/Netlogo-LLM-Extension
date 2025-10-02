# NetLogo Multi-LLM Extension - Setup Guide

## Quick Start

1. **Download Extension**: Copy `llm.jar` to your NetLogo extensions folder
2. **Create Config**: Copy and edit `demos/config.txt` for your provider
3. **Load Extension**: Add `extensions [llm]` to your NetLogo model
4. **Load Config**: Run `llm:load-config "config.txt"` in your code
5. **Start Chatting**: Use `llm:chat "Hello, world!"` to test

## Installation

### Step 1: Install the Extension

Place `llm.jar` in your NetLogo extensions directory:

**Windows**: `C:\Users\[username]\AppData\Roaming\NetLogo\[version]\extensions\`
**Mac**: `~/Library/Application Support/NetLogo/[version]/extensions/`
**Linux**: `~/.netlogo/[version]/extensions/`

### Step 2: Verify NetLogo Version

This extension requires **NetLogo 7.0.0 or later**. Check your version in NetLogo:
- Help → About NetLogo

## Provider Setup

### OpenAI (GPT Models)

1. **Get API Key**: Visit [platform.openai.com](https://platform.openai.com/api-keys)
2. **Create config.txt**:
```
provider=openai
model=gpt-4o-mini
api_key=sk-your-openai-key-here
temperature=0.7
max_tokens=1000
```

**Available Models**:
- `gpt-4o-mini` - Fast, cost-effective (recommended)
- `gpt-4o` - Most capable GPT-4 variant
- `gpt-4-turbo` - Faster GPT-4 with large context
- `gpt-3.5-turbo` - Legacy model, still capable

### Anthropic (Claude Models)

1. **Get API Key**: Visit [console.anthropic.com](https://console.anthropic.com/)
2. **Create config.txt**:
```
provider=anthropic
model=claude-3-haiku-20240307
api_key=sk-ant-your-anthropic-key-here
temperature=0.5
max_tokens=4000
```

**Available Models**:
- `claude-3-haiku-20240307` - Fast, cost-effective (recommended)
- `claude-3-sonnet-20240229` - Balanced performance
- `claude-3-opus-20240229` - Most capable Claude
- `claude-3-5-sonnet-20241022` - Latest improved Sonnet

### Google Gemini

1. **Get API Key**: Visit [aistudio.google.com](https://aistudio.google.com/app/apikey)
2. **Create config.txt**:
```
provider=gemini
model=gemini-1.5-flash
api_key=your-google-ai-api-key-here
temperature=0.8
max_tokens=2048
```

**Available Models**:
- `gemini-1.5-flash` - Fast, free tier available (recommended)
- `gemini-1.5-pro` - Most capable Gemini
- `gemini-pro` - Original Gemini Pro

### Ollama (Local Models)

1. **Install Ollama**: Download from [ollama.ai](https://ollama.ai/)
2. **Start Server**: Run `ollama serve` in terminal
3. **Pull Model**: Run `ollama pull llama3.2`
4. **Create config.txt**:
```
provider=ollama
model=llama3.2
temperature=0.7
max_tokens=2048
timeout_seconds=60
```

**Popular Models** (must pull first):
- `llama3.2` - Latest Llama (recommended)
- `llama3.1` - Previous Llama version
- `mistral` - Mistral 7B
- `codellama` - Code-specialized Llama
- `deepseek-r1:1.5b` - Reasoning model

**Pull command**: `ollama pull [model-name]`

## Configuration Parameters

### Core Settings

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `provider` | LLM provider (`openai`, `anthropic`, `gemini`, `ollama`) | Yes | - |
| `model` | Model identifier | Yes | Provider-specific |
| `api_key` | API authentication key | Yes* | - |
| `temperature` | Response randomness (0.0-1.0) | No | 0.7 |
| `max_tokens` | Maximum response length | No | 1000 |
| `timeout_seconds` | Request timeout | No | 30 |

*Not required for Ollama

### Advanced Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `base_url` | Custom API endpoint | Provider default |

### Provider-Specific Defaults

**OpenAI**:
- `base_url`: `https://api.openai.com/v1`
- `max_tokens`: 1000

**Anthropic**:
- `base_url`: `https://api.anthropic.com/v1`
- `max_tokens`: 4000

**Gemini**:
- `base_url`: `https://generativelanguage.googleapis.com/v1beta`
- `max_tokens`: 2048

**Ollama**:
- `base_url`: `http://localhost:11434`
- `max_tokens`: 2048
- `timeout_seconds`: 60

## Testing Your Setup

1. **Create Test Model**:
```netlogo
extensions [llm]

to setup
  llm:load-config "config.txt"
  print "Extension loaded successfully!"
end

to test-chat
  let response llm:chat "Hello! Please respond with exactly: 'Setup successful!'"
  print response
end
```

2. **Run Test**:
   - Click `setup` button
   - Click `test-chat` button  
   - Check Command Center for "Setup successful!" response

## Troubleshooting

### Common Issues

**"Extension not found"**
- Ensure `llm.jar` is in correct extensions directory
- Restart NetLogo after copying extension

**"Provider not found"**
- Check `provider=` line in config.txt
- Verify spelling: `openai`, `anthropic`, `gemini`, `ollama`

**"API key invalid"**
- Verify API key is correct and active
- Check key format matches provider requirements
- Ensure sufficient API credits/quota

**"Model not found"**
- For Ollama: Run `ollama pull [model-name]` first
- For cloud providers: Check model availability in your tier

**"Connection timeout"**
- Increase `timeout_seconds` in config
- For Ollama: Ensure `ollama serve` is running
- Check network connectivity

**"Rate limited"**
- Wait and retry
- Consider upgrading API tier
- Reduce request frequency

### Getting Help

1. Check the [demos](demos/) folder for working examples
2. Review [API-REFERENCE.md](API-REFERENCE.md) for detailed usage
3. Test with simple prompts first
4. Enable debug logging if available

## Next Steps

- Read [API-REFERENCE.md](API-REFERENCE.md) for complete primitive documentation
- Explore [demos/](demos/) for example NetLogo models
- See [EXAMPLES.md](EXAMPLES.md) for common usage patterns
