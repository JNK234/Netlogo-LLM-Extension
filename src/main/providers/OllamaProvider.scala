// ABOUTME: Ollama provider implementation for local Ollama models
// ABOUTME: Handles API communication with local Ollama server using the LLMProvider interface

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
 * Ollama provider implementation for local Ollama models
 */
class OllamaProvider(implicit ec: ExecutionContext) extends LLMProvider {

  private val configStore = new ConfigStore()
  private val backend = HttpClientFutureBackend()

  // Set default configuration
  configStore.set(ConfigStore.PROVIDER, "ollama")
  configStore.set(ConfigStore.MODEL, defaultModel)
  configStore.set(ConfigStore.BASE_URL, "http://localhost:11434")
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
      throw new RuntimeException("No response message received from Ollama")
    ))
  }

  private def sendChatRequest(request: ChatRequest): Future[ChatResponse] = {
    val baseUrl = configStore.getOrElse(ConfigStore.BASE_URL, "http://localhost:11434")
    val apiUrl = uri"$baseUrl/api/chat"

    val headers = Map(
      "Content-Type" -> "application/json"
    )

    // Convert our request format to Ollama's format
    val ollamaRequest = createOllamaRequest(request)
    val requestBody = ollamaRequest.toString()

    val httpRequest = basicRequest
      .headers(headers)
      .body(requestBody)
      .post(apiUrl)

    httpRequest.send(backend).map { response =>
      response.body match {
        case Right(responseBody) =>
          parseOllamaResponse(responseBody, request.model)
        case Left(error) =>
          throw new RuntimeException(s"HTTP request failed: $error")
      }
    }
  }

  private def createOllamaRequest(request: ChatRequest): ujson.Value = {
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
      "messages" -> messages,
      "stream" -> false // We want a single response, not streaming
    )

    // Add options if parameters are specified
    val options = ujson.Obj()
    var hasOptions = false

    request.temperature.foreach { temp =>
      options("temperature") = temp
      hasOptions = true
    }

    request.maxTokens.foreach { maxTokens =>
      options("num_predict") = maxTokens
      hasOptions = true
    }

    if (hasOptions) {
      baseRequest("options") = options
    }

    baseRequest
  }

  private def parseOllamaResponse(responseBody: String, model: String): ChatResponse = {
    try {
      val parsed = ujson.read(responseBody)

      val id = s"ollama-${System.currentTimeMillis()}" // Ollama doesn't provide ID
      val created = System.currentTimeMillis() / 1000

      val message = parsed("message")
      val role = message("role").str
      val content = message("content").str
      val doneReason = if (parsed("done").bool) "stop" else "length"

      val choices = Array(
        org.nlogo.extensions.llm.models.Choice(
          index = 0,
          message = ChatMessage(role, content),
          finishReason = doneReason
        )
      )

      ChatResponse(id, created, model, choices)
    } catch {
      case e: Exception =>
        throw new RuntimeException(s"Failed to parse Ollama response: ${e.getMessage}\nResponse: $responseBody")
    }
  }

  override def setConfig(key: String, value: String): Unit = {
    configStore.set(key, value)
  }

  override def getConfig(key: String): Option[String] = {
    configStore.get(key)
  }

  override def validateConfig(): Try[Unit] = {
    // Ollama typically doesn't require an API key, just the base URL
    Success(())
  }

  override def providerName: String = "ollama"

  override def defaultModel: String = "llama3.2"

  override def supportsModel(model: String): Boolean = {
    ModelRegistry.isValidModel("ollama", model)
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
    s"Ollama Provider - ${configStore.summary}"
  }

  /**
   * Check if Ollama server is accessible
   */
  def checkServerConnection(): Future[Boolean] = {
    val baseUrl = configStore.getOrElse(ConfigStore.BASE_URL, "http://localhost:11434")
    val apiUrl = uri"$baseUrl/api/tags"

    val httpRequest = basicRequest.get(apiUrl)

    httpRequest.send(backend).map { response =>
      response.isSuccess
    }.recover {
      case _ => false
    }
  }

  /**
   * List installed models from Ollama server
   * 
   * @return Future containing set of installed model names
   */
  def listInstalledModels(): Future[Set[String]] = {
    val baseUrl = configStore.getOrElse(ConfigStore.BASE_URL, "http://localhost:11434")
    val apiUrl = uri"$baseUrl/api/tags"

    val httpRequest = basicRequest.get(apiUrl)

    httpRequest.send(backend).map { response =>
      response.body match {
        case Right(responseBody) =>
          try {
            val parsed = ujson.read(responseBody)
            val models = parsed("models").arr
            models.map { model =>
              model("name").str
            }.toSet
          } catch {
            case _: Exception => Set.empty[String]
          }
        case Left(_) => Set.empty[String]
      }
    }.recover {
      case _ => Set.empty[String]
    }
  }
}
