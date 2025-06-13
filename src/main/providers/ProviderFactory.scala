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
        Failure(new UnsupportedOperationException(
          s"Anthropic provider not yet implemented. Supported providers: ${SUPPORTED_PROVIDERS.mkString(", ")}"
        ))
        
      case GEMINI =>
        Failure(new UnsupportedOperationException(
          s"Gemini provider not yet implemented. Supported providers: ${SUPPORTED_PROVIDERS.mkString(", ")}"
        ))
        
      case OLLAMA =>
        Failure(new UnsupportedOperationException(
          s"Ollama provider not yet implemented. Supported providers: ${SUPPORTED_PROVIDERS.mkString(", ")}"
        ))
        
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
  def getImplementedProviders: Set[String] = Set(OPENAI)
  
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
      case _ =>
        Success(()) // Other providers when implemented
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
    config.get(ConfigStore.MODEL).foreach { model =>
      if (!isValidOpenAIModel(model)) {
        return Failure(new IllegalArgumentException(
          s"Unsupported OpenAI model: '$model'. Supported models: ${getOpenAISupportedModels.mkString(", ")}"
        ))
      }
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
        ConfigStore.MODEL -> ConfigStore.DEFAULT_OPENAI_MODEL,
        ConfigStore.BASE_URL -> ConfigStore.DEFAULT_OPENAI_BASE_URL,
        ConfigStore.TEMPERATURE -> ConfigStore.DEFAULT_TEMPERATURE,
        ConfigStore.MAX_TOKENS -> ConfigStore.DEFAULT_MAX_TOKENS
      )
      case _ => Map() // Other providers when implemented
    }
  }
}