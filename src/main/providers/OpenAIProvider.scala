package org.nlogo.extensions.llm.providers

import org.nlogo.extensions.llm.models.{ChatMessage, ChatRequest, ChatResponse}
import org.nlogo.extensions.llm.config.ConfigStore
import sttp.client4._
import sttp.client4.httpclient.HttpClientFutureBackend
import upickle.default.{read, write}
import ujson._
import scala.concurrent.{Future, ExecutionContext}
import scala.util.{Try, Success, Failure}

/**
 * OpenAI provider implementation for GPT models
 */
class OpenAIProvider(implicit ec: ExecutionContext) extends LLMProvider {

  private val configStore = new ConfigStore()
  private val backend = HttpClientFutureBackend()

  // Set default configuration
  configStore.set(ConfigStore.PROVIDER, "openai")
  configStore.set(ConfigStore.MODEL, ConfigStore.DEFAULT_OPENAI_MODEL)
  configStore.set(ConfigStore.BASE_URL, ConfigStore.DEFAULT_OPENAI_BASE_URL)
  configStore.set(ConfigStore.TEMPERATURE, ConfigStore.DEFAULT_TEMPERATURE)
  configStore.set(ConfigStore.MAX_TOKENS, ConfigStore.DEFAULT_MAX_TOKENS)

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
      throw new RuntimeException("No response message received from OpenAI")
    ))
  }

  private def sendChatRequest(request: ChatRequest): Future[ChatResponse] = {
    val apiKey = configStore.get(ConfigStore.API_KEY).getOrElse(
      throw new IllegalStateException("API key not configured")
    )

    val baseUrl = configStore.getOrElse(ConfigStore.BASE_URL, ConfigStore.DEFAULT_OPENAI_BASE_URL)
    val apiUrl = uri"$baseUrl/chat/completions"

    val headers = Map(
      "Authorization" -> s"Bearer $apiKey",
      "Content-Type" -> "application/json"
    )

    // Convert our request format to OpenAI's format
    val openAIRequest = createOpenAIRequest(request)
    val requestBody = openAIRequest.toString()

    val httpRequest = basicRequest
      .headers(headers)
      .body(requestBody)
      .post(apiUrl)

    httpRequest.send(backend).map { response =>
      response.body match {
        case Right(responseBody) =>
          parseOpenAIResponse(responseBody, request.model)
        case Left(error) =>
          throw new RuntimeException(s"HTTP request failed: $error")
      }
    }
  }

  private def createOpenAIRequest(request: ChatRequest): ujson.Value = {
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

  private def parseOpenAIResponse(responseBody: String, model: String): ChatResponse = {
    try {
      val parsed = ujson.read(responseBody)

      val id = parsed("id").str
      val created = parsed("created").num.toLong
      val choices = parsed("choices").arr.zipWithIndex.map { case (choice, index) =>
        val message = choice("message")
        val role = message("role").str
        val content = message("content").str
        val finishReason = choice("finish_reason").str

        org.nlogo.extensions.llm.models.Choice(
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

  override def providerName: String = "openai"

  override def defaultModel: String = ConfigStore.DEFAULT_OPENAI_MODEL

  override def supportsModel(model: String): Boolean = {
    val supportedModels = Set(
      "gpt-4", "gpt-4-turbo", "gpt-4-turbo-preview",
      "gpt-3.5-turbo", "gpt-3.5-turbo-16k",
      "gpt-4o", "gpt-4o-mini"
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
    s"OpenAI Provider - ${configStore.summary}"
  }
}
