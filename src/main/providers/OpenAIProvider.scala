// ABOUTME: OpenAI provider implementation for GPT models
// ABOUTME: Extends BaseHttpProvider with OpenAI-specific request/response formatting

package org.nlogo.extensions.llm.providers

import org.nlogo.extensions.llm.models.{ChatMessage, ChatRequest, ChatResponse, Choice}
import org.nlogo.extensions.llm.config.ConfigStore
import sttp.client4._
import sttp.model.Uri
import ujson._
import scala.concurrent.ExecutionContext

/**
 * OpenAI provider implementation for GPT models
 */
class OpenAIProvider(implicit ec: ExecutionContext) extends BaseHttpProvider {

  override def providerName: String = "openai"

  override def defaultModel: String = ConfigStore.DEFAULT_OPENAI_MODEL

  override protected def defaultBaseUrl: String = ConfigStore.DEFAULT_OPENAI_BASE_URL

  override protected def baseUrlConfigKey: String = ConfigStore.OPENAI_BASE_URL

  override protected def apiKeyConfigKey: String = ConfigStore.OPENAI_API_KEY

  override protected def defaultMaxTokens: String = ConfigStore.DEFAULT_MAX_TOKENS

  override protected def requiresApiKey: Boolean = true

  override protected def buildApiUrl(baseUrl: String): Uri = {
    uri"$baseUrl/chat/completions"
  }

  override protected def buildHeaders(apiKey: Option[String]): Map[String, String] = Map(
    "Authorization" -> s"Bearer ${apiKey.get}",
    "Content-Type" -> "application/json"
  )

  override protected def createProviderRequest(request: ChatRequest): ujson.Value = {
    val messages = ujson.Arr(
      request.messages.map { msg =>
        ujson.Obj(
          "role" -> msg.role,
          "content" -> msg.content
        )
      }*
    )

    val baseRequest = ujson.Obj(
      "model" -> request.model,
      "messages" -> messages
    )

    request.maxTokens.foreach { maxTokens =>
      baseRequest("max_tokens") = maxTokens
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
      val created = parsed("created").num.toLong
      val choices = parsed("choices").arr.zipWithIndex.map { case (choice, index) =>
        val message = choice("message")
        val role = message("role").str
        val content = message("content").str
        val finishReason = choice("finish_reason").str

        Choice(
          index = index,
          message = ChatMessage(role, content),
          finishReason = finishReason
        )
      }.toArray

      ChatResponse(id, created, model, choices)
    } catch {
      case e: Exception =>
        throw new RuntimeException(s"Failed to parse OpenAI response: ${e.getMessage}\nResponse: $responseBody")
    }
  }
}
