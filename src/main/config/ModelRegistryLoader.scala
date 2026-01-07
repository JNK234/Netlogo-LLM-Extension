// ABOUTME: Loads and merges model registry configurations from bundled YAML and optional override files
// ABOUTME: Provides model lists per provider with custom model counting
package org.nlogo.extensions.llm.config

import scala.util.{Try, Success, Failure}
import scala.io.Source
import io.circe.yaml.parser
import io.circe.{Json, HCursor}
import java.nio.file.{Files, Paths}
import java.nio.charset.StandardCharsets

/**
 * Container for provider model lists
 *
 * @param models Set of model identifiers for this provider
 * @param isCustom Whether these models come from a custom/override configuration
 */
case class ProviderModels(models: Set[String], isCustom: Boolean = false)

/**
 * Utility for loading and merging model registry configurations
 *
 * The model registry defines which models are available for each provider.
 * Configuration can come from:
 * 1. Bundled config in JAR resources (/config/models.yaml)
 * 2. Override config in model directory (models-override.yaml)
 */
object ModelRegistryLoader {

  /**
   * Load the bundled model configuration from JAR resources
   *
   * Loads /config/models.yaml from the JAR's resources directory.
   *
   * @return Try containing Map of provider name to ProviderModels
   */
  def loadBundledConfig(): Try[Map[String, ProviderModels]] = {
    Try {
      val resourceStream = getClass.getResourceAsStream("/config/models.yaml")

      if (resourceStream == null) {
        throw new IllegalArgumentException(
          "Bundled model configuration not found: /config/models.yaml must be present in JAR resources"
        )
      }

      val source = Source.fromInputStream(resourceStream)
      try {
        val content = source.mkString
        parseModelConfig(content, isCustom = false)
      } finally {
        source.close()
        resourceStream.close()
      }
    }.flatten
  }

  /**
   * Load override model configuration from a directory
   *
   * Loads models-override.yaml from the specified directory.
   * Returns both the configuration and a count of custom models.
   *
   * @param modelDir Directory containing the models-override.yaml file
   * @return Try containing tuple of (provider map, custom model count)
   */
  def loadOverrideConfig(modelDir: String): Try[(Map[String, ProviderModels], Int)] = {
    val possiblePaths = Seq(
      Paths.get(modelDir, "models-override.yaml"),
      Paths.get(modelDir, "models-override.yml")
    )

    val path = possiblePaths.find(Files.exists(_))

    path match {
      case Some(p) =>
        parseModelConfig(
          Files.readString(p, StandardCharsets.UTF_8),
          isCustom = true
        ).map { config =>
          val customCount = config.values.map(_.models.size).sum
          (config, customCount)
        }

      case None =>
        // Override file is optional - return empty config with 0 custom models
        Success((Map.empty[String, ProviderModels], 0))
    }
  }

  /**
   * Merge bundled and override configurations
   *
   * Override sections completely replace bundled sections for each provider.
   * If a provider exists in override config, its bundled config is ignored.
   *
   * @param bundled The bundled configuration from JAR resources
   * @param overrideConfig The override configuration from model directory
   * @return Merged configuration map
   */
  def mergeConfigs(
    bundled: Map[String, ProviderModels],
    overrideConfig: Map[String, ProviderModels]
  ): Map[String, ProviderModels] = {
    // Start with bundled config, then overlay override config
    // Override completely replaces bundled for each provider key
    bundled ++ overrideConfig
  }

  /**
   * Parse YAML model configuration content
   *
   * Expected YAML structure:
   * ```yaml
   * openai:
   *   - gpt-4o
   *   - gpt-4o-mini
   * anthropic:
   *   - claude-3-5-sonnet
   * ```
   *
   * @param content YAML content as string
   * @param isCustom Whether this config comes from a custom/override source
   * @return Try containing Map of provider name to ProviderModels
   */
  private def parseModelConfig(content: String, isCustom: Boolean): Try[Map[String, ProviderModels]] = {
    Try {
      parser.parse(content) match {
        case Right(json) =>
          val cursor: HCursor = json.hcursor

          // Get all top-level keys (provider names)
          val providers = json.asObject.getOrElse(
            throw new RuntimeException("YAML root must be an object with provider names as keys")
          ).keys.toSeq

          // Parse each provider's model list
          val config = providers.map { provider =>
            val models = cursor.downField(provider).as[Seq[String]] match {
              case Right(modelList) =>
                if (modelList.isEmpty) {
                  throw new RuntimeException(s"Provider '$provider' has empty model list")
                }
                modelList.toSet

              case Left(error) =>
                throw new RuntimeException(
                  s"Failed to parse model list for provider '$provider': ${error.getMessage}"
                )
            }

            provider -> ProviderModels(models, isCustom)
          }.toMap

          if (config.isEmpty) {
            throw new RuntimeException("Model configuration is empty - at least one provider must be defined")
          }

          config

        case Left(error) =>
          throw new RuntimeException(s"Failed to parse YAML: ${error.getMessage}")
      }
    }
  }
}
