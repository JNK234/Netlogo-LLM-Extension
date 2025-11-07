package org.nlogo.extensions.llm.providers

/**
 * Central registry for supported LLM models across all providers
 * 
 * This registry provides a single source of truth for:
 * - Supported models per provider
 * - Default models per provider
 * - Model validation
 * 
 * Update this file to add new models or providers.
 */
object ModelRegistry {

  /**
   * OpenAI supported models
   * Updated with latest GPT-4o, o1, o3, o4 families
   */
  private val OPENAI_MODELS: Set[String] = Set(
    // GPT-4o family (latest, recommended)
    "gpt-4o",
    "gpt-4o-mini",
    
    // GPT-4 family
    "gpt-4",
    "gpt-4-turbo",
    "gpt-4-turbo-preview",
    
    // GPT-3.5 family (legacy)
    "gpt-3.5-turbo",
    "gpt-3.5-turbo-16k",
    
    // o-series (reasoning models)
    "o1",
    "o1-mini",
    "o1-preview",
    
    // o3-series
    "o3-mini",
    "o3-mini-high",
    
    // o4-series
    "o4-mini"
  )

  /**
   * Anthropic Claude supported models
   * Updated to current Claude 3 and 3.5 families
   */
  private val ANTHROPIC_MODELS: Set[String] = Set(
    // Claude 3.5 family (latest)
    "claude-3-5-sonnet-20241022",
    "claude-3-5-sonnet-latest",
    "claude-3-5-haiku-20241022",
    "claude-3-5-haiku-latest",
    
    // Claude 3 family
    "claude-3-opus-20240229",
    "claude-3-sonnet-20240229",
    "claude-3-haiku-20240307"
  )

  /**
   * Google Gemini supported models
   * Updated with Gemini 1.5 and 2.0 families
   */
  private val GEMINI_MODELS: Set[String] = Set(
    // Gemini 2.0 family (latest)
    "gemini-2.0-flash-exp",
    "gemini-2.0-flash-thinking-exp",
    
    // Gemini 1.5 family (stable, recommended)
    "gemini-1.5-pro",
    "gemini-1.5-flash",
    "gemini-1.5-flash-8b",
    
    // Gemini 1.0 family (legacy)
    "gemini-1.0-pro",
    "gemini-pro"
  )

  /**
   * Ollama supported models (curated common list)
   * Note: Actual available models depend on local installation
   */
  private val OLLAMA_MODELS: Set[String] = Set(
    // Llama family
    "llama3.2",
    "llama3.1",
    "llama3",
    "llama2",
    
    // Mistral family
    "mistral",
    "mistral-nemo",
    "mixtral",
    
    // Code models
    "codellama",
    "deepseek-coder",
    "qwen2.5-coder",
    
    // Other popular models
    "phi3",
    "phi4",
    "gemma",
    "gemma2",
    "qwen2",
    "qwen2.5",
    "vicuna",
    "orca-mini",
    "neural-chat",
    
    // DeepSeek
    "deepseek-r1",
    "deepseek-r1:1.5b",
    "deepseek-r1:3b",
    "deepseek-r1:7b",
    "deepseek-r1:8b",
    "deepseek-r1:14b",
    "deepseek-r1:32b",
    "deepseek-r1:70b"
  )

  /**
   * Get supported models for a provider
   * 
   * @param providerName Provider name (case-insensitive)
   * @return Set of supported model names
   */
  def getSupportedModels(providerName: String): Set[String] = {
    providerName.toLowerCase.trim match {
      case "openai" => OPENAI_MODELS
      case "anthropic" => ANTHROPIC_MODELS
      case "gemini" => GEMINI_MODELS
      case "ollama" => OLLAMA_MODELS
      case _ => Set.empty[String]
    }
  }

  /**
   * Get default model for a provider
   * 
   * @param providerName Provider name (case-insensitive)
   * @return Default model name
   */
  def defaultModel(providerName: String): String = {
    providerName.toLowerCase.trim match {
      case "openai" => "gpt-4o-mini"
      case "anthropic" => "claude-3-5-haiku-latest"
      case "gemini" => "gemini-1.5-flash"
      case "ollama" => "llama3.2"
      case _ => throw new IllegalArgumentException(s"Unknown provider: $providerName")
    }
  }

  /**
   * Check if a model is valid for a provider
   * 
   * @param providerName Provider name (case-insensitive)
   * @param model Model name
   * @return true if the model is supported by the provider
   */
  def isValidModel(providerName: String, model: String): Boolean = {
    getSupportedModels(providerName).contains(model)
  }

  /**
   * Get all provider names that have models registered
   * 
   * @return Set of provider names
   */
  def getAllProviders: Set[String] = {
    Set("openai", "anthropic", "gemini", "ollama")
  }

  /**
   * Get a user-friendly list of supported models for error messages
   * 
   * @param providerName Provider name
   * @return Formatted string of models
   */
  def getModelListForDisplay(providerName: String): String = {
    val models = getSupportedModels(providerName).toList.sorted
    if (models.isEmpty) {
      "No models available"
    } else if (models.size <= 10) {
      models.mkString(", ")
    } else {
      // Show first 10 and indicate there are more
      val firstTen = models.take(10).mkString(", ")
      s"$firstTen, ... (${models.size} total)"
    }
  }
}

