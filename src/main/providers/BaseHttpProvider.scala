// ABOUTME: Abstract base class for HTTP-based LLM providers, consolidating common functionality
// ABOUTME: Reduces boilerplate by providing shared implementation of config, validation, and HTTP request handling
package org.nlogo.extensions.llm.providers

import org.nlogo.extensions.llm.models.{ChatMessage, ChatRequest, ChatResponse}
import org.nlogo.extensions.llm.config.ConfigStore
import sttp.client4._
import sttp.client4.httpclient.HttpClientFutureBackend
import sttp.model.Uri
import ujson._
import scala.concurrent.{Future, ExecutionContext}
import scala.util.{Try, Success, Failure}

/**
 * Abstract base class for HTTP-based LLM providers
 *
 * Consolidates common functionality to reduce boilerplate in provider implementations.
 * Subclasses only need to implement provider-specific request/response formatting.
 */
abstract class BaseHttpProvider(implicit ec: ExecutionContext) extends LLMProvider {

  protected val configStore = new ConfigStore()
  protected val backend = HttpClientFutureBackend()

  // Initialize with provider-specific defaults
  initializeDefaults()

  // Abstract methods for provider-specific behavior
  def providerName: String
  def defaultModel: String
  protected def defaultBaseUrl: String
  protected def baseUrlConfigKey: String
  protected def apiKeyConfigKey: String
  protected def defaultMaxTokens: String
  protected def requiresApiKey: Boolean

  protected def buildApiUrl(baseUrl: String): Uri
  protected def buildHeaders(apiKey: Option[String]): Map[String, String]
  protected def createProviderRequest(request: ChatRequest): ujson.Value
  protected def parseProviderResponse(responseBody: String, model: String): ChatResponse

  /**
   * Initialize provider-specific default configuration
   */
  protected def initializeDefaults(): Unit = {
    configStore.set(ConfigStore.PROVIDER, providerName)
    configStore.set(ConfigStore.MODEL, defaultModel)
    configStore.set(baseUrlConfigKey, defaultBaseUrl)
    configStore.set(ConfigStore.TEMPERATURE, ConfigStore.DEFAULT_TEMPERATURE)
    configStore.set(ConfigStore.MAX_TOKENS, defaultMaxTokens)
  }

  /**
   * Send a chat request with validation
   */
  override def chat(request: ChatRequest): Future[ChatResponse] = {
    validateConfig() match {
      case Success(_) => sendChatRequest(request)
      case Failure(e) => Future.failed(e)
    }
  }

  /**
   * Simplified chat method that takes messages directly
   */
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
      throw new RuntimeException(s"No response message received from $providerName")
    ))
  }

  /**
   * Send the actual HTTP request
   */
  protected def sendChatRequest(request: ChatRequest): Future[ChatResponse] = {
    val apiKey = if (requiresApiKey) {
      Some(configStore.get(apiKeyConfigKey)
        .orElse(configStore.get(ConfigStore.API_KEY))
        .getOrElse(throw new IllegalStateException("API key not configured")))
    } else {
      configStore.get(apiKeyConfigKey).orElse(configStore.get(ConfigStore.API_KEY))
    }

    val baseUrl = configStore.get(baseUrlConfigKey).getOrElse(defaultBaseUrl)
    val apiUrl = buildApiUrl(baseUrl)
    val headers = buildHeaders(apiKey)
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

  override def setConfig(key: String, value: String): Unit = {
    configStore.set(key, value)
  }

  override def getConfig(key: String): Option[String] = {
    configStore.get(key)
  }

  override def validateConfig(): Try[Unit] = {
    if (requiresApiKey) {
      val hasKey = configStore.get(apiKeyConfigKey).orElse(configStore.get(ConfigStore.API_KEY)).isDefined
      if (!hasKey) {
        Failure(new IllegalStateException(s"$providerName requires an API key"))
      } else {
        Success(())
      }
    } else {
      Success(())
    }
  }

  override def supportsModel(model: String): Boolean = {
    ModelRegistry.isValidModel(providerName, model)
  }

  /**
   * Load configuration from external map
   */
  def loadConfig(config: Map[String, String]): Unit = {
    configStore.updateFromMap(config)
  }

  /**
   * Get configuration summary for debugging
   */
  def getConfigSummary: String = {
    s"$providerName Provider - ${configStore.summary}"
  }
}
