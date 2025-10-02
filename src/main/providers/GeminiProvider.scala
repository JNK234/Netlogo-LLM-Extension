// ABOUTME: Google Gemini provider implementation for Gemini models
// ABOUTME: Handles API communication with Google's Gemini API using the LLMProvider interface

package org.nlogo.extensions.llm.providers

import org.nlogo.extensions.llm.models.{ChatMessage, ChatRequest, ChatResponse}
import org.nlogo.extensions.llm.config.ConfigStore
import sttp.client3._
import upickle.default.{read, write}
import ujson._
import scala.concurrent.{Future, ExecutionContext}
import scala.util.{Try, Success, Failure}

/**
 * Google Gemini provider implementation for Gemini models
 */
class GeminiProvider(implicit ec: ExecutionContext) extends LLMProvider {

  private val configStore = new ConfigStore()
  private val backend = HttpClientFutureBackend()

  // Set default configuration
  configStore.set(ConfigStore.PROVIDER, "gemini")
  configStore.set(ConfigStore.MODEL, defaultModel)
  configStore.set(ConfigStore.BASE_URL, "https://generativelanguage.googleapis.com/v1beta")
  configStore.set(ConfigStore.TEMPERATURE, ConfigStore.DEFAULT_TEMPERATURE)
  configStore.set(ConfigStore.MAX_TOKENS, "2048")

  override def chat(request: ChatRequest): Future[ChatResponse] = {
    validateConfig() match {
      case Success(_) => sendChatRequest(request)
      case Failure(e) => Future.failed(e)
    }
  }

  override def chat(messages: Seq[ChatMessage]): Future[ChatMessage] = {
    val model = configStore.getOrElse(ConfigStore.MODEL, defaultModel)
    val temperature = configStore.get(ConfigStore.TEMPERATURE).map(_.toDouble)
    val maxTokens = configStore.get(ConfigStore.MAX_TOKENS).map(_.toInt)

    val request = ChatRequest(
      model = model,
      messages = messages,
      maxTokens = maxTokens,
      temperature = temperature
    )

    chat(request).map(_.firstMessage.getOrElse(
      throw new RuntimeException("No response message received from Gemini")
    ))
  }

  private def sendChatRequest(request: ChatRequest): Future[ChatResponse] = {
    val apiKey = configStore.get(ConfigStore.API_KEY).getOrElse(
      throw new IllegalStateException("API key not configured")
    )

    val baseUrl = configStore.getOrElse(ConfigStore.BASE_URL, "https://generativelanguage.googleapis.com/v1beta")
    val apiUrl = uri"$baseUrl/models/${request.model}:generateContent?key=$apiKey"

    val headers = Map(
      "Content-Type" -> "application/json"
    )

    // Convert our request format to Gemini's format
    val geminiRequest = createGeminiRequest(request)
    val requestBody = geminiRequest.toString()

    val httpRequest = basicRequest
      .headers(headers)
      .body(requestBody)
      .post(apiUrl)

    httpRequest.send(backend).map { response =>
      response.body match {
        case Right(responseBody) =>
          parseGeminiResponse(responseBody, request.model)
        case Left(error) =>
          throw new RuntimeException(s"HTTP request failed: $error")
      }
    }
  }

  private def createGeminiRequest(request: ChatRequest): ujson.Value = {
    // Gemini expects messages in a different format
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

  private def parseGeminiResponse(responseBody: String, model: String): ChatResponse = {
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

  override def setConfig(key: String, value: String): Unit = {
    configStore.set(key, value)
  }

  override def getConfig(key: String): Option[String] = {
    configStore.get(key)
  }

  override def validateConfig(): Try[Unit] = {
    val requiredKeys = Set(ConfigStore.API_KEY)
    configStore.validateRequired(requiredKeys)
  }

  override def providerName: String = "gemini"

  override def defaultModel: String = "gemini-1.5-flash"

  override def supportsModel(model: String): Boolean = {
    val supportedModels = Set(
      "gemini-1.5-pro",
      "gemini-1.5-flash",
      "gemini-1.0-pro",
      "gemini-pro"
    )
    supportedModels.contains(model)
  }

  /**
   * Load configuration from external map (e.g., from config file)
   */
  def loadConfig(config: Map[String, String]): Unit = {
    configStore.updateFromMap(config)
  }

  /**
   * Get configuration summary for debugging
   */
  def getConfigSummary: String = {
    s"Gemini Provider - ${configStore.summary}"
  }
}
