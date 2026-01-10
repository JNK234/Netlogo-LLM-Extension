// ABOUTME: Google Gemini provider implementation for Gemini models
// ABOUTME: Handles API communication with Google's Gemini API using the LLMProvider interface

package org.nlogo.extensions.llm.providers

import org.nlogo.extensions.llm.models.{ChatMessage, ChatRequest, ChatResponse}
import org.nlogo.extensions.llm.config.ConfigStore
import sttp.client4._
import sttp.model.Uri
import ujson._
import scala.concurrent.ExecutionContext

/**
 * Google Gemini provider implementation for Gemini models
 *
 * Gemini has unique requirements:
 * - API key is passed as a query parameter, not in headers
 * - Model name is included in the URL path
 * - Uses "contents" array with "parts" for message formatting
 * - Maps "assistant" role to "model" role
 */
class GeminiProvider(implicit ec: ExecutionContext) extends BaseHttpProvider {

  override def providerName: String = "gemini"

  override def defaultModel: String = ModelRegistry.defaultModel("gemini")

  override protected def defaultBaseUrl: String = ConfigStore.DEFAULT_GEMINI_BASE_URL

  override protected def baseUrlConfigKey: String = ConfigStore.GEMINI_BASE_URL

  override protected def apiKeyConfigKey: String = ConfigStore.GEMINI_API_KEY

  override protected def defaultMaxTokens: String = "2048"

  override protected def requiresApiKey: Boolean = true

  /**
   * Override sendChatRequest to handle Gemini's unique URL construction
   *
   * Gemini requires:
   * - Model name in the URL path
   * - API key as a query parameter (not in headers)
   */
  override protected def sendChatRequest(request: ChatRequest): scala.concurrent.Future[ChatResponse] = {
    val apiKey = configStore.get(apiKeyConfigKey)
      .orElse(configStore.get(ConfigStore.API_KEY))
      .getOrElse(throw new IllegalStateException("API key not configured"))

    val baseUrl = configStore.get(baseUrlConfigKey).getOrElse(defaultBaseUrl)
    val apiUrl = uri"$baseUrl/models/${request.model}:generateContent?key=$apiKey"

    val headers = Map("Content-Type" -> "application/json")
    val requestBody = createProviderRequest(request).toString()

    val httpRequest = basicRequest
      .headers(headers)
      .body(requestBody)
      .post(apiUrl)

    httpRequest.send(backend).map { response =>
      response.body match {
        case Right(responseBody) =>
          parseProviderResponse(responseBody, request.model)
        case Left(error) =>
          throw new RuntimeException(s"HTTP request failed: $error")
      }
    }
  }

  /**
   * Build Gemini API URL - not used as we override sendChatRequest
   */
  override protected def buildApiUrl(baseUrl: String): Uri = {
    // Not used - Gemini needs model name which isn't available here
    throw new UnsupportedOperationException("Use sendChatRequest override instead")
  }

  /**
   * Build headers for Gemini - not used as we override sendChatRequest
   */
  override protected def buildHeaders(apiKey: Option[String]): Map[String, String] = {
    // Not used - we override sendChatRequest
    throw new UnsupportedOperationException("Use sendChatRequest override instead")
  }

  /**
   * Convert ChatRequest to Gemini's request format
   *
   * Gemini expects:
   * - "contents" array with "role" and "parts"
   * - Role mapping: "assistant" → "model", "user" → "user"
   * - "generationConfig" for optional parameters (temperature, maxOutputTokens)
   */
  override protected def createProviderRequest(request: ChatRequest): ujson.Value = {
    // Convert messages to Gemini's format
    val contents = ujson.Arr(
      request.messages.map { msg =>
        val role = if (msg.role == "assistant") "model" else "user"
        ujson.Obj(
          "role" -> role,
          "parts" -> ujson.Arr(
            ujson.Obj("text" -> msg.content)
          )
        )
      }*
    )

    val baseRequest = ujson.Obj(
      "contents" -> contents
    )

    // Add generation config if parameters are specified
    val generationConfig = ujson.Obj()
    var hasConfig = false

    request.temperature.foreach { temp =>
      generationConfig("temperature") = temp
      hasConfig = true
    }

    request.maxTokens.foreach { maxTokens =>
      generationConfig("maxOutputTokens") = maxTokens
      hasConfig = true
    }

    if (hasConfig) {
      baseRequest("generationConfig") = generationConfig
    }

    baseRequest
  }

  /**
   * Parse Gemini's response format into ChatResponse
   *
   * Gemini returns:
   * - "candidates" array with "content" and "finishReason"
   * - Content has "parts" array with "text"
   */
  override protected def parseProviderResponse(responseBody: String, model: String): ChatResponse = {
    try {
      val parsed = ujson.read(responseBody)

      val id = s"gemini-${System.currentTimeMillis()}" // Gemini doesn't provide ID
      val created = System.currentTimeMillis() / 1000

      val candidates = parsed("candidates").arr
      val candidate = candidates.head
      val content = candidate("content")
      val parts = content("parts").arr
      val text = parts.head("text").str
      val finishReason = candidate("finishReason").str

      val choices = Array(
        org.nlogo.extensions.llm.models.Choice(
          index = 0,
          message = ChatMessage("assistant", text),
          finishReason = finishReason
        )
      )

      ChatResponse(id, created, model, choices)
    } catch {
      case e: Exception =>
        throw new RuntimeException(s"Failed to parse Gemini response: ${e.getMessage}\nResponse: $responseBody")
    }
  }
}
