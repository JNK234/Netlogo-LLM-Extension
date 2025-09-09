package org.nlogo.extensions.llm.providers

import org.nlogo.extensions.llm.config.ConfigStore
import scala.concurrent.ExecutionContext
import scala.util.{Try, Success, Failure}

/**
 * Factory for creating LLM provider instances
 * 
 * This factory implements the Factory pattern to create provider instances
 * based on configuration. It supports easy extension for new providers.
 */
object ProviderFactory {
  
  // Supported provider names
  val OPENAI = "openai"
  val ANTHROPIC = "anthropic"
  val GEMINI = "gemini"
  val OLLAMA = "ollama"
  
  // Set of all supported providers
  val SUPPORTED_PROVIDERS: Set[String] = Set(OPENAI, ANTHROPIC, GEMINI, OLLAMA)
  
  /**
   * Create a provider instance by name
   * 
   * @param providerName Name of the provider to create
   * @param ec ExecutionContext for async operations
   * @return Try containing the provider instance
   */
  def createProvider(providerName: String)(implicit ec: ExecutionContext): Try[LLMProvider] = {
    val normalizedName = providerName.toLowerCase.trim
    
    normalizedName match {
      case OPENAI => 
        Try(new OpenAIProvider())
        
      case ANTHROPIC =>
        Try(new ClaudeProvider())
        
      case GEMINI =>
        Try(new GeminiProvider())
        
      case OLLAMA =>
        Try(new OllamaProvider())
        
      case unknown =>
        Failure(new IllegalArgumentException(
          s"Unknown provider: '$unknown'. Supported providers: ${SUPPORTED_PROVIDERS.mkString(", ")}"
        ))
    }
  }
  
  /**
   * Create a provider instance with configuration
   * 
   * @param providerName Name of the provider to create
   * @param config Configuration map to apply to the provider
   * @param ec ExecutionContext for async operations
   * @return Try containing the configured provider instance
   */
  def createProvider(providerName: String, config: Map[String, String])(implicit ec: ExecutionContext): Try[LLMProvider] = {
    createProvider(providerName).map { provider =>
      // Apply configuration to the provider
      config.foreach { case (key, value) =>
        provider.setConfig(key, value)
      }
      provider
    }
  }
  
  /**
   * Create a provider from a ConfigStore
   * 
   * @param configStore ConfigStore containing provider configuration
   * @param ec ExecutionContext for async operations
   * @return Try containing the configured provider instance
   */
  def createProviderFromConfig(configStore: ConfigStore)(implicit ec: ExecutionContext): Try[LLMProvider] = {
    val providerName = configStore.getOrElse(ConfigStore.PROVIDER, ConfigStore.DEFAULT_PROVIDER)
    val config = configStore.toMap
    
    createProvider(providerName, config)
  }
  
  /**
   * Validate that a provider name is supported
   * 
   * @param providerName Name to validate
   * @return true if the provider is supported
   */
  def isSupported(providerName: String): Boolean = {
    SUPPORTED_PROVIDERS.contains(providerName.toLowerCase.trim)
  }
  
  /**
   * Get list of supported provider names
   * 
   * @return Set of supported provider names
   */
  def getSupportedProviders: Set[String] = SUPPORTED_PROVIDERS
  
  /**
   * Get list of currently implemented providers
   * 
   * @return Set of implemented provider names
   */
  def getImplementedProviders: Set[String] = Set(OPENAI, ANTHROPIC, GEMINI, OLLAMA)
  
  /**
   * Check if a provider is implemented
   * 
   * @param providerName Name to check
   * @return true if the provider is implemented
   */
  def isImplemented(providerName: String): Boolean = {
    getImplementedProviders.contains(providerName.toLowerCase.trim)
  }
  
  /**
   * Validate provider configuration
   * 
   * @param providerName Provider name
   * @param config Configuration map
   * @return Try[Unit] - Success if valid, Failure with error if invalid
   */
  def validateProviderConfig(providerName: String, config: Map[String, String]): Try[Unit] = {
    if (!isSupported(providerName)) {
      return Failure(new IllegalArgumentException(
        s"Unsupported provider: '$providerName'. Supported: ${SUPPORTED_PROVIDERS.mkString(", ")}"
      ))
    }
    
    if (!isImplemented(providerName)) {
      return Failure(new UnsupportedOperationException(
        s"Provider '$providerName' is planned but not yet implemented"
      ))
    }
    
    // Provider-specific validation
    providerName.toLowerCase.trim match {
      case OPENAI =>
        validateOpenAIConfig(config)
      case ANTHROPIC =>
        validateClaudeConfig(config)
      case GEMINI =>
        validateGeminiConfig(config)
      case OLLAMA =>
        validateOllamaConfig(config)
      case _ =>
        Success(()) // Should not reach here given earlier validation
    }
  }
  
  /**
   * Validate OpenAI-specific configuration
   */
  private def validateOpenAIConfig(config: Map[String, String]): Try[Unit] = {
    val apiKey = config.get(ConfigStore.API_KEY)
    
    if (apiKey.isEmpty) {
      return Failure(new IllegalArgumentException("OpenAI provider requires 'api_key' configuration"))
    }
    
    val key = apiKey.get
    if (key.trim.isEmpty) {
      return Failure(new IllegalArgumentException("OpenAI API key cannot be empty"))
    }
    
    if (!key.startsWith("sk-")) {
      return Failure(new IllegalArgumentException("OpenAI API key should start with 'sk-'"))
    }
    
    // Validate model if specified
    config.get(ConfigStore.MODEL) match {
      case Some(model) =>
        if (!isValidOpenAIModel(model)) {
          return Failure(new IllegalArgumentException(
            s"Unsupported OpenAI model: '$model'. Supported models: ${getOpenAISupportedModels.mkString(", ")}"
          ))
        }
      case None => // Model is optional, will use default
    }
    
    Success(())
  }
  
  /**
   * Validate Claude-specific configuration
   */
  private def validateClaudeConfig(config: Map[String, String]): Try[Unit] = {
    val apiKey = config.get(ConfigStore.API_KEY)
    
    if (apiKey.isEmpty) {
      return Failure(new IllegalArgumentException("Claude provider requires 'api_key' configuration"))
    }
    
    val key = apiKey.get
    if (key.trim.isEmpty) {
      return Failure(new IllegalArgumentException("Claude API key cannot be empty"))
    }
    
    // Validate model if specified
    config.get(ConfigStore.MODEL) match {
      case Some(model) =>
        if (!isValidClaudeModel(model)) {
          return Failure(new IllegalArgumentException(
            s"Unsupported Claude model: '$model'. Supported models: ${getClaudeSupportedModels.mkString(", ")}"
          ))
        }
      case None => // Model is optional, will use default
    }
    
    Success(())
  }
  
  /**
   * Validate Gemini-specific configuration
   */
  private def validateGeminiConfig(config: Map[String, String]): Try[Unit] = {
    val apiKey = config.get(ConfigStore.API_KEY)
    
    if (apiKey.isEmpty) {
      return Failure(new IllegalArgumentException("Gemini provider requires 'api_key' configuration"))
    }
    
    val key = apiKey.get
    if (key.trim.isEmpty) {
      return Failure(new IllegalArgumentException("Gemini API key cannot be empty"))
    }
    
    // Validate model if specified
    config.get(ConfigStore.MODEL) match {
      case Some(model) =>
        if (!isValidGeminiModel(model)) {
          return Failure(new IllegalArgumentException(
            s"Unsupported Gemini model: '$model'. Supported models: ${getGeminiSupportedModels.mkString(", ")}"
          ))
        }
      case None => // Model is optional, will use default
    }
    
    Success(())
  }
  
  /**
   * Validate Ollama-specific configuration
   */
  private def validateOllamaConfig(config: Map[String, String]): Try[Unit] = {
    // Ollama typically doesn't require API key, just base URL
    
    // Validate model if specified
    config.get(ConfigStore.MODEL) match {
      case Some(model) =>
        if (!isValidOllamaModel(model)) {
          return Failure(new IllegalArgumentException(
            s"Unsupported Ollama model: '$model'. Supported models: ${getOllamaSupportedModels.mkString(", ")}"
          ))
        }
      case None => // Model is optional, will use default
    }
    
    Success(())
  }
  
  /**
   * Check if an OpenAI model is supported
   */
  private def isValidOpenAIModel(model: String): Boolean = {
    getOpenAISupportedModels.contains(model)
  }
  
  /**
   * Get list of supported OpenAI models
   */
  private def getOpenAISupportedModels: Set[String] = {
    Set(
      "gpt-4", "gpt-4-turbo", "gpt-4-turbo-preview",
      "gpt-3.5-turbo", "gpt-3.5-turbo-16k",
      "gpt-4o", "gpt-4o-mini"
    )
  }
  
  /**
   * Check if a Claude model is supported
   */
  private def isValidClaudeModel(model: String): Boolean = {
    getClaudeSupportedModels.contains(model)
  }
  
  /**
   * Get list of supported Claude models
   */
  private def getClaudeSupportedModels: Set[String] = {
    Set(
      "claude-3-opus-20240229",
      "claude-3-sonnet-20240229", 
      "claude-3-haiku-20240307",
      "claude-3-5-sonnet-20241022"
    )
  }
  
  /**
   * Check if a Gemini model is supported
   */
  private def isValidGeminiModel(model: String): Boolean = {
    getGeminiSupportedModels.contains(model)
  }
  
  /**
   * Get list of supported Gemini models
   */
  private def getGeminiSupportedModels: Set[String] = {
    Set(
      "gemini-1.5-pro",
      "gemini-1.5-flash",
      "gemini-1.0-pro",
      "gemini-pro"
    )
  }
  
  /**
   * Check if an Ollama model is supported
   */
  private def isValidOllamaModel(model: String): Boolean = {
    getOllamaSupportedModels.contains(model)
  }
  
  /**
   * Get list of supported Ollama models
   */
  private def getOllamaSupportedModels: Set[String] = {
    Set(
      "llama3.2", "llama3.1", "llama3", "llama2",
      "mistral", "mixtral", "codellama", "vicuna",
      "phi3", "gemma", "qwen2", "deepseek-coder"
    )
  }
  
  /**
   * Get provider-specific configuration requirements
   * 
   * @param providerName Provider name
   * @return Set of required configuration keys
   */
  def getRequiredConfigKeys(providerName: String): Set[String] = {
    providerName.toLowerCase.trim match {
      case OPENAI => Set(ConfigStore.API_KEY)
      case ANTHROPIC => Set(ConfigStore.API_KEY)
      case GEMINI => Set(ConfigStore.API_KEY)
      case OLLAMA => Set() // Ollama typically doesn't require API key
      case _ => Set()
    }
  }
  
  /**
   * Get provider-specific default configuration
   * 
   * @param providerName Provider name
   * @return Map of default configuration values
   */
  def getDefaultConfig(providerName: String): Map[String, String] = {
    providerName.toLowerCase.trim match {
      case OPENAI => Map(
        ConfigStore.MODEL -> "gpt-4o",
        ConfigStore.BASE_URL -> ConfigStore.DEFAULT_OPENAI_BASE_URL,
        ConfigStore.TEMPERATURE -> ConfigStore.DEFAULT_TEMPERATURE,
        ConfigStore.MAX_TOKENS -> ConfigStore.DEFAULT_MAX_TOKENS
      )
      case ANTHROPIC => Map(
        ConfigStore.MODEL -> "claude-3-sonnet-20240229",
        ConfigStore.BASE_URL -> "https://api.anthropic.com/v1",
        ConfigStore.TEMPERATURE -> ConfigStore.DEFAULT_TEMPERATURE,
        ConfigStore.MAX_TOKENS -> "4000"
      )
      case GEMINI => Map(
        ConfigStore.MODEL -> "gemini-1.5-pro",
        ConfigStore.BASE_URL -> "https://generativelanguage.googleapis.com/v1beta",
        ConfigStore.TEMPERATURE -> ConfigStore.DEFAULT_TEMPERATURE,
        ConfigStore.MAX_TOKENS -> "2048"
      )
      case OLLAMA => Map(
        ConfigStore.MODEL -> "llama3",
        ConfigStore.BASE_URL -> "http://localhost:11434",
        ConfigStore.TEMPERATURE -> ConfigStore.DEFAULT_TEMPERATURE,
        ConfigStore.MAX_TOKENS -> "2048"
      )
      case _ => Map() // Should not reach here given earlier validation
    }
  }
}