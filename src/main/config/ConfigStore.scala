package org.nlogo.extensions.llm.config

import scala.collection.mutable
import scala.util.{Try, Success, Failure}

/**
 * In-memory configuration storage and management
 *
 * This class provides thread-safe storage and retrieval of configuration
 * key-value pairs with support for validation and defaults.
 */
class ConfigStore {
  private val config = mutable.Map[String, String]()
  private val lock = new Object

  /**
   * Set a configuration value
   *
   * @param key Configuration key
   * @param value Configuration value
   */
  def set(key: String, value: String): Unit = {
    lock.synchronized {
      config(key) = value
    }
  }

  /**
   * Get a configuration value
   *
   * @param key Configuration key
   * @return Option containing the value if it exists
   */
  def get(key: String): Option[String] = {
    lock.synchronized {
      config.get(key)
    }
  }

  /**
   * Get a configuration value with a default
   *
   * @param key Configuration key
   * @param default Default value if key is not found
   * @return The configuration value or default
   */
  def getOrElse(key: String, default: String): String = {
    lock.synchronized {
      config.getOrElse(key, default)
    }
  }

  /**
   * Check if a configuration key exists
   *
   * @param key Configuration key
   * @return true if the key exists
   */
  def contains(key: String): Boolean = {
    lock.synchronized {
      config.contains(key)
    }
  }

  /**
   * Remove a configuration key
   *
   * @param key Configuration key to remove
   * @return Option containing the removed value
   */
  def remove(key: String): Option[String] = {
    lock.synchronized {
      config.remove(key)
    }
  }

  /**
   * Clear all configuration
   */
  def clear(): Unit = {
    lock.synchronized {
      config.clear()
    }
  }

  /**
   * Load configuration from a map, replacing existing values
   *
   * @param newConfig Map of configuration key-value pairs
   */
  def loadFromMap(newConfig: Map[String, String]): Unit = {
    lock.synchronized {
      config.clear()
      config ++= newConfig
    }
  }

  /**
   * Update configuration from a map, merging with existing values
   *
   * @param newConfig Map of configuration key-value pairs
   */
  def updateFromMap(newConfig: Map[String, String]): Unit = {
    lock.synchronized {
      config ++= newConfig
    }
  }

  /**
   * Get all configuration as an immutable map
   *
   * @return Map containing all configuration key-value pairs
   */
  def toMap: Map[String, String] = {
    lock.synchronized {
      config.toMap
    }
  }

  /**
   * Get all configuration keys
   *
   * @return Set of all configuration keys
   */
  def keys: Set[String] = {
    lock.synchronized {
      config.keySet.toSet
    }
  }

  /**
   * Validate that required keys are present
   *
   * @param requiredKeys Set of required configuration keys
   * @return Try[Unit] - Success if all required keys present, Failure otherwise
   */
  def validateRequired(requiredKeys: Set[String]): Try[Unit] = {
    lock.synchronized {
      val missingKeys = requiredKeys -- config.keySet

      if (missingKeys.nonEmpty) {
        Failure(new IllegalStateException(
          s"Missing required configuration keys: ${missingKeys.mkString(", ")}"
        ))
      } else {
        Success(())
      }
    }
  }

  /**
   * Get configuration summary for debugging
   *
   * @return String representation of configuration (values masked for security)
   */
  def summary: String = {
    lock.synchronized {
      config.map { case (key, value) =>
        val maskedValue = if (key.toLowerCase.contains("key") || key.toLowerCase.contains("secret")) {
          if (value.length > 8) s"${value.take(4)}...${value.takeRight(4)}" else "***"
        } else {
          value
        }
        s"$key=$maskedValue"
      }.mkString(", ")
    }
  }
}

/**
 * Companion object with common configuration keys
 */
object ConfigStore {
  // Common configuration keys
  val PROVIDER = "provider"
  val API_KEY = "api_key"
  val MODEL = "model"
  val BASE_URL = "base_url"
  val TEMPERATURE = "temperature"
  val MAX_TOKENS = "max_tokens"
  val TIMEOUT_SECONDS = "timeout_seconds"
  
  // Per-provider API keys
  val OPENAI_API_KEY = "openai_api_key"
  val ANTHROPIC_API_KEY = "anthropic_api_key"
  val GEMINI_API_KEY = "gemini_api_key"
  
  // Per-provider base URLs
  val OPENAI_BASE_URL = "openai_base_url"
  val ANTHROPIC_BASE_URL = "anthropic_base_url"
  val GEMINI_BASE_URL = "gemini_base_url"
  val OLLAMA_BASE_URL = "ollama_base_url"
  
  // Reserved for future use
  val INFERENCE_URL = "inference_url"

  // Default values
  val DEFAULT_PROVIDER = "openai"
  val DEFAULT_OPENAI_MODEL = "gpt-4o-mini"
  val DEFAULT_OPENAI_BASE_URL = "https://api.openai.com/v1"
  val DEFAULT_ANTHROPIC_BASE_URL = "https://api.anthropic.com/v1"
  val DEFAULT_GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta"
  val DEFAULT_OLLAMA_BASE_URL = "http://localhost:11434"
  val DEFAULT_TEMPERATURE = "0.7"
  val DEFAULT_MAX_TOKENS = "1000"
  val DEFAULT_TIMEOUT_SECONDS = "30"

  /**
   * Create a new ConfigStore with default values
   */
  def withDefaults(): ConfigStore = {
    val store = new ConfigStore()
    store.set(PROVIDER, DEFAULT_PROVIDER)
    store.set(MODEL, DEFAULT_OPENAI_MODEL)
    store.set(BASE_URL, DEFAULT_OPENAI_BASE_URL)
    store.set(TEMPERATURE, DEFAULT_TEMPERATURE)
    store.set(MAX_TOKENS, DEFAULT_MAX_TOKENS)
    store.set(TIMEOUT_SECONDS, DEFAULT_TIMEOUT_SECONDS)
    store
  }
  
  /**
   * Get the provider-specific API key constant name
   * 
   * @param provider Provider name
   * @return API key config constant
   */
  def getProviderApiKeyName(provider: String): String = {
    provider.toLowerCase.trim match {
      case "openai" => OPENAI_API_KEY
      case "anthropic" => ANTHROPIC_API_KEY
      case "gemini" => GEMINI_API_KEY
      case _ => API_KEY
    }
  }
  
  /**
   * Get the provider-specific base URL constant name
   * 
   * @param provider Provider name
   * @return Base URL config constant
   */
  def getProviderBaseUrlName(provider: String): String = {
    provider.toLowerCase.trim match {
      case "openai" => OPENAI_BASE_URL
      case "anthropic" => ANTHROPIC_BASE_URL
      case "gemini" => GEMINI_BASE_URL
      case "ollama" => OLLAMA_BASE_URL
      case _ => BASE_URL
    }
  }
  
  /**
   * Get default base URL for a provider
   * 
   * @param provider Provider name
   * @return Default base URL
   */
  def getDefaultBaseUrl(provider: String): String = {
    provider.toLowerCase.trim match {
      case "openai" => DEFAULT_OPENAI_BASE_URL
      case "anthropic" => DEFAULT_ANTHROPIC_BASE_URL
      case "gemini" => DEFAULT_GEMINI_BASE_URL
      case "ollama" => DEFAULT_OLLAMA_BASE_URL
      case _ => ""
    }
  }
}
