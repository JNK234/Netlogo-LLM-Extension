// ABOUTME: Anthropic Claude provider implementation for Claude models
// ABOUTME: Extends BaseHttpProvider with Claude-specific request/response formatting and authentication

package org.nlogo.extensions.llm.providers

import org.nlogo.extensions.llm.models.{ChatMessage, ChatRequest, ChatResponse}
import org.nlogo.extensions.llm.config.ConfigStore
import sttp.client4._
import sttp.model.Uri
import ujson._
import scala.concurrent.ExecutionContext

/**
 * Anthropic Claude provider implementation for Claude models
 *
 * Extends BaseHttpProvider with Claude-specific behavior:
 * - Uses x-api-key header instead of Bearer token
 * - Requires anthropic-version header
 * - Separates system messages from other messages in request format
 */
class ClaudeProvider(implicit ec: ExecutionContext) extends BaseHttpProvider {

  override def providerName: String = "anthropic"

  override def defaultModel: String = ModelRegistry.defaultModel("anthropic")

  override protected def defaultBaseUrl: String = ConfigStore.DEFAULT_ANTHROPIC_BASE_URL

  override protected def baseUrlConfigKey: String = ConfigStore.ANTHROPIC_BASE_URL

  override protected def apiKeyConfigKey: String = ConfigStore.ANTHROPIC_API_KEY

  override protected def defaultMaxTokens: String = "4000"

  override protected def requiresApiKey: Boolean = true

  override protected def buildApiUrl(baseUrl: String): Uri = {
    uri"$baseUrl/messages"
  }

  override protected def buildHeaders(apiKey: Option[String]): Map[String, String] = {
    // Note: This reads ENABLE_THINKING from the provider's configStore, which stays in sync
    // because LLMExtension invalidates the provider (currentProvider = None) on thinking config changes.
    val thinkingEnabled = configStore.get(ConfigStore.ENABLE_THINKING).exists(_.toLowerCase == "true")
    val version = if (thinkingEnabled) "2025-04-15" else "2023-06-01"
    Map(
      "x-api-key" -> apiKey.getOrElse(throw new IllegalStateException("API key required for Claude")),
      "content-type" -> "application/json",
      "anthropic-version" -> version
    )
  }

  override protected def createProviderRequest(request: ChatRequest): ujson.Value = {
    val isThinking = request.thinkingConfig.exists(_.enabled)

    // Claude API expects system message separate from other messages
    val (systemMessage, userMessages) = request.messages.partition(_.role == "system")

    val messages = ujson.Arr(
      userMessages.map { msg =>
        ujson.Obj(
          "role" -> msg.role,
          "content" -> msg.content
        )
      }*
    )

    val maxTokens = request.maxTokens.getOrElse(4000)

    val baseRequest = ujson.Obj(
      "model" -> request.model,
      "messages" -> messages,
      "max_tokens" -> maxTokens
    )

    // Add system message if present
    systemMessage.headOption.foreach { sysMsg =>
      baseRequest("system") = sysMsg.content
    }

    if (isThinking) {
      // Anthropic requires budget >= 1024 AND budget < max_tokens, so max_tokens must be > 1024
      if (maxTokens <= 1024) {
        throw new RuntimeException(
          s"Claude thinking requires max_tokens > 1024 (current: $maxTokens). " +
          "The thinking budget must be at least 1024 and less than max_tokens."
        )
      }

      // Anthropic requires temperature=1.0 when thinking is enabled
      baseRequest("temperature") = 1.0

      // Budget must be >= 1024 and < max_tokens
      val budget = request.thinkingConfig.flatMap(_.budgetTokens)
        .map(b => math.max(1024, math.min(b, maxTokens - 1)))
        .getOrElse(math.max(1024, math.min(4096, maxTokens - 1)))

      baseRequest("thinking") = ujson.Obj(
        "type" -> "enabled",
        "budget_tokens" -> budget
      )
    } else {
      request.temperature.foreach { temp =>
        baseRequest("temperature") = temp
      }
    }

    baseRequest
  }

  override protected def parseProviderResponse(responseBody: String, model: String): ChatResponse = {
    try {
      val parsed = ujson.read(responseBody)

      val id = parsed("id").str
      val created = System.currentTimeMillis() / 1000 // Claude doesn't provide created timestamp

      val contentBlocks = parsed("content").arr

      // Separate thinking blocks from text blocks
      val thinkingBlocks = contentBlocks.filter(b =>
        scala.util.Try(b("type").str).toOption.contains("thinking")
      )
      val thinkingTexts = thinkingBlocks.flatMap { b =>
        scala.util.Try(b("thinking").str).toOption.orElse {
          System.err.println(s"WARNING: Claude thinking block present but could not extract thinking text: $b")
          None
        }
      }

      val textBlocks = contentBlocks.filter(b =>
        scala.util.Try(b("type").str).toOption.contains("text")
      )

      // Fall back to first block if no explicit text blocks found
      val text = if (textBlocks.nonEmpty) {
        textBlocks.map { b =>
          scala.util.Try(b("text").str).getOrElse {
            System.err.println(s"WARNING: Claude text block missing 'text' field: $b")
            ""
          }
        }.mkString
      } else {
        contentBlocks.headOption.flatMap { b =>
          scala.util.Try(b("text").str).toOption
        }.getOrElse {
          System.err.println(s"WARNING: No text blocks found in Claude response, falling back to empty string. Content blocks: $contentBlocks")
          ""
        }
      }

      val thinking = if (thinkingTexts.nonEmpty) Some(thinkingTexts.mkString("\n")) else None

      val choices = Array(
        org.nlogo.extensions.llm.models.Choice(
          index = 0,
          message = ChatMessage("assistant", text),
          finishReason = parsed("stop_reason").str
        )
      )

      ChatResponse(id, created, model, choices, thinking = thinking)
    } catch {
      case e: Exception =>
        throw new RuntimeException(s"Failed to parse Claude response: ${e.getMessage}\nResponse: $responseBody", e)
    }
  }
}
