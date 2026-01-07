package org.nlogo.extensions.llm.providers

import org.nlogo.extensions.llm.config.{ModelRegistryLoader, ProviderModels}
import scala.util.{Try, Success, Failure}

/**
 * Central registry for supported LLM models across all providers
 *
 * This registry provides a single source of truth for:
 * - Supported models per provider (loaded from YAML configs)
 * - Default models per provider
 * - Model validation
 * - Custom model tracking
 *
 * Models are loaded from:
 * 1. Bundled YAML config in JAR resources (/config/models.yaml)
 * 2. Optional override config (models-override.yaml) in model directory
 */
object ModelRegistry {

  // Lock for thread-safe access to mutable state
  private val lock = new Object

  // Mutable state for dynamic loading (access must be synchronized)
  private var providers: Map[String, ProviderModels] = Map.empty
  private var isInitialized: Boolean = false
  private var modelDirLoaded: Option[String] = None
  private var overrideLoadMessage: Option[String] = None

  // Fallback config in case YAML loading fails (minimal set for stability)
  private val FALLBACK_CONFIG: Map[String, ProviderModels] = Map(
    "openai" -> ProviderModels(Set("gpt-4o", "gpt-4o-mini", "gpt-4", "gpt-3.5-turbo"), isCustom = false),
    "anthropic" -> ProviderModels(Set(
      "claude-3-5-sonnet-20241022", "claude-3-5-sonnet-latest",
      "claude-3-5-haiku-20241022", "claude-3-5-haiku-latest"
    ), isCustom = false),
    "gemini" -> ProviderModels(Set("gemini-1.5-pro", "gemini-1.5-flash", "gemini-2.0-flash-exp"), isCustom = false),
    "ollama" -> ProviderModels(Set("llama3.2", "llama3.1", "mistral", "phi4"), isCustom = false)
  )

  /**
   * Initialize the registry by loading bundled configuration
   *
   * This is called automatically on first use, but can be called explicitly.
   * Safe to call multiple times - will only initialize once unless reset.
   */
  def init(): Unit = lock.synchronized {
    if (isInitialized) return

    ModelRegistryLoader.loadBundledConfig() match {
      case Success(config) =>
        providers = config
        isInitialized = true

      case Failure(error) =>
        // Fall back to hardcoded minimal config if YAML loading fails
        System.err.println(s"WARNING: Failed to load bundled model config: ${error.getMessage}")
        System.err.println("WARNING: Using fallback hardcoded model registry")
        providers = FALLBACK_CONFIG
        isInitialized = true
    }
  }

  /**
   * Load override configuration from a model directory
   *
   * Merges override config with bundled config. Override takes precedence.
   * Returns a notification message if custom models were loaded.
   *
   * @param modelDir Directory containing models-override.yaml
   * @return Some(message) if override loaded with custom model count, None otherwise
   */
  def loadOverride(modelDir: String): Option[String] = lock.synchronized {
    ensureInitialized()

    ModelRegistryLoader.loadOverrideConfig(modelDir) match {
      case Success((overrideConfig, customCount)) =>
        if (overrideConfig.nonEmpty) {
          providers = ModelRegistryLoader.mergeConfigs(providers, overrideConfig)
          modelDirLoaded = Some(modelDir)
          val message = s"Loaded $customCount custom models from override config"
          overrideLoadMessage = Some(message)
          Some(message)
        } else {
          None
        }

      case Failure(error) =>
        System.err.println(s"WARNING: Failed to load override config: ${error.getMessage}")
        None
    }
  }

  /**
   * Check if a specific model is from custom/override configuration
   *
   * @param providerName Provider name (case-insensitive)
   * @param model Model name
   * @return true if the model exists and is from override config
   */
  def isCustomModel(providerName: String, model: String): Boolean = {
    ensureInitialized()
    val normalizedProvider = providerName.toLowerCase.trim
    providers.get(normalizedProvider) match {
      case Some(pm) if pm.isCustom && pm.models.contains(model) => true
      case _ => false
    }
  }

  /**
   * Check if an entire provider's model list is from override configuration
   *
   * @param providerName Provider name (case-insensitive)
   * @return true if the provider exists and is from override config
   */
  def isProviderCustom(providerName: String): Boolean = {
    ensureInitialized()
    val normalizedProvider = providerName.toLowerCase.trim
    providers.get(normalizedProvider).exists(_.isCustom)
  }

  /**
   * Format a complete model list for display (used by llm:list-models)
   *
   * @param activeProvider Currently active provider name
   * @param activeModel Currently active model name
   * @return Formatted string showing all providers and models with markers
   */
  def formatModelList(activeProvider: String, activeModel: String): String = {
    ensureInitialized()

    val normalizedActiveProvider = activeProvider.toLowerCase.trim
    val lines = new StringBuilder()

    lines.append("=== Available Models ===\n")

    // Sort providers alphabetically for consistent output
    providers.keys.toSeq.sorted.foreach { provider =>
      lines.append(s"\n--- $provider ---\n")

      val pm = providers(provider)
      val sortedModels = pm.models.toSeq.sorted

      sortedModels.foreach { model =>
        val markers = new StringBuilder()

        // Add [ACTIVE] marker
        if (provider == normalizedActiveProvider && model == activeModel) {
          markers.append(" [ACTIVE]")
        }

        // Add [custom] marker
        if (pm.isCustom || isCustomModel(provider, model)) {
          markers.append(" [custom]")
        }

        lines.append(s"  $model${markers.toString}\n")
      }
    }

    lines.append(s"\nCurrently using: $normalizedActiveProvider / $activeModel\n")
    lines.toString
  }

  /**
   * Reset the registry to uninitialized state (for testing)
   *
   * Clears all loaded configuration and state.
   */
  def reset(): Unit = lock.synchronized {
    providers = Map.empty
    isInitialized = false
    modelDirLoaded = None
    overrideLoadMessage = None
  }

  /**
   * Ensure the registry is initialized before use
   *
   * Called internally by all public methods that need data.
   */
  private def ensureInitialized(): Unit = lock.synchronized {
    if (!isInitialized) init()
  }

  /**
   * Get supported models for a provider
   *
   * @param providerName Provider name (case-insensitive)
   * @return Set of supported model names
   */
  def getSupportedModels(providerName: String): Set[String] = {
    ensureInitialized()
    val normalizedProvider = providerName.toLowerCase.trim
    providers.get(normalizedProvider).map(_.models).getOrElse(Set.empty[String])
  }

  /**
   * Get default model for a provider
   *
   * These defaults are hardcoded as they represent stable, recommended models.
   * They do not change based on YAML configuration.
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
    ensureInitialized()
    getSupportedModels(providerName).contains(model)
  }

  /**
   * Get all provider names that have models registered
   *
   * @return Set of provider names
   */
  def getAllProviders: Set[String] = {
    ensureInitialized()
    providers.keySet
  }

  /**
   * Get a user-friendly list of supported models for error messages
   *
   * @param providerName Provider name
   * @return Formatted string of models
   */
  def getModelListForDisplay(providerName: String): String = {
    ensureInitialized()
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

