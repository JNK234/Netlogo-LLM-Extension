// ABOUTME: Central registry of provider descriptors, populated at extension load time
// ABOUTME: Single source of truth for provider metadata — replaces scattered match/case lookups
package org.nlogo.extensions.llm.providers

/**
 * Singleton registry holding ProviderDescriptor for every supported provider.
 *
 * Populated once during extension initialization via ProviderRegistrations.registerAll().
 * All consumer code (ProviderFactory, LLMExtension, ConfigStore helpers, etc.)
 * reads from this registry instead of maintaining per-provider match/case blocks.
 *
 * Thread-safety: registration happens on the main thread at load time before
 * any NetLogo model code runs. After init the map is effectively read-only.
 */
object ProviderRegistry {

  @volatile private var descriptors: Map[String, ProviderDescriptor] = Map.empty

  /**
   * Register a provider descriptor. Call during extension init only.
   * Uses @volatile to ensure the full map is visible to any thread that
   * reads after registration completes (safe-publication guarantee).
   */
  def register(desc: ProviderDescriptor): Unit = {
    descriptors = descriptors + (desc.name.toLowerCase.trim -> desc)
  }

  /** Look up a descriptor by provider name (case-insensitive). */
  def get(name: String): Option[ProviderDescriptor] =
    descriptors.get(name.toLowerCase.trim)

  /** All registered provider names. */
  def allNames: Set[String] = descriptors.keySet

  /** Whether a provider name is registered. */
  def isSupported(name: String): Boolean =
    descriptors.contains(name.toLowerCase.trim)

  // --- Convenience accessors that replace scattered match/case ---

  def apiKeyConfigKey(provider: String): String =
    get(provider).map(_.apiKeyConfigKey).getOrElse("api_key")

  def baseUrlConfigKey(provider: String): String =
    get(provider).map(_.baseUrlConfigKey).getOrElse("base_url")

  def defaultBaseUrl(provider: String): String =
    get(provider).map(_.defaultBaseUrl).getOrElse("")

  def defaultModel(provider: String): String =
    get(provider).map(_.defaultModel)
      .getOrElse(throw new IllegalArgumentException(s"Unknown provider: $provider"))

  def requiresApiKey(provider: String): Boolean =
    get(provider).exists(_.requiresApiKey)

  def helpText(provider: String): String =
    get(provider).map(_.helpText)
      .getOrElse(s"Unknown provider: $provider. Supported: ${allNames.mkString(", ")}")

  def exposesThinking(provider: String): Boolean =
    get(provider).exists(_.exposesThinking)

  /** Whether any providers have been registered. */
  def isInitialized: Boolean = descriptors.nonEmpty

  /** Reset registry — for testing only. */
  def reset(): Unit = {
    descriptors = Map.empty
  }
}
