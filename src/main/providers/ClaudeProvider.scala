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
    Map(
      "x-api-key" -> apiKey.getOrElse(throw new IllegalStateException("API key required for Claude")),
      "content-type" -> "application/json",
      "anthropic-version" -> "2023-06-01"
    )
  }

  override protected def createProviderRequest(request: ChatRequest): ujson.Value = {
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

    val baseRequest = ujson.Obj(
      "model" -> request.model,
      "messages" -> messages,
      "max_tokens" -> request.maxTokens.getOrElse(4000)
    )

    // Add system message if present
    systemMessage.headOption.foreach { sysMsg =>
      baseRequest("system") = sysMsg.content
    }

    request.temperature.foreach { temp =>
      baseRequest("temperature") = temp
    }

    baseRequest
  }

  override protected def parseProviderResponse(responseBody: String, model: String): ChatResponse = {
    try {
      val parsed = ujson.read(responseBody)

      val id = parsed("id").str
      val created = System.currentTimeMillis() / 1000 // Claude doesn't provide created timestamp

      val content = parsed("content").arr.head
      val text = content("text").str

      val choices = Array(
        org.nlogo.extensions.llm.models.Choice(
          index = 0,
          message = ChatMessage("assistant", text),
          finishReason = parsed("stop_reason").str
        )
      )

      ChatResponse(id, created, model, choices)
    } catch {
      case e: Exception =>
        throw new RuntimeException(s"Failed to parse Claude response: ${e.getMessage}\nResponse: $responseBody")
    }
  }
}
