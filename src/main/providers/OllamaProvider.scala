// ABOUTME: Ollama provider implementation for local Ollama models
// ABOUTME: Handles API communication with local Ollama server using BaseHttpProvider

package org.nlogo.extensions.llm.providers

import org.nlogo.extensions.llm.models.{ChatMessage, ChatRequest, ChatResponse}
import org.nlogo.extensions.llm.config.ConfigStore
import sttp.client4._
import sttp.model.Uri
import ujson._
import scala.concurrent.{Future, ExecutionContext}

/**
 * Ollama provider implementation for local Ollama models
 *
 * Extends BaseHttpProvider to reduce boilerplate. Ollama runs locally and
 * does not require an API key.
 */
class OllamaProvider(implicit ec: ExecutionContext) extends BaseHttpProvider {

  override val providerName: String = "ollama"
  override val defaultModel: String = ModelRegistry.defaultModel("ollama")
  override protected val defaultBaseUrl: String = ConfigStore.DEFAULT_OLLAMA_BASE_URL
  override protected val baseUrlConfigKey: String = ConfigStore.OLLAMA_BASE_URL
  override protected val apiKeyConfigKey: String = ConfigStore.API_KEY
  override protected val defaultMaxTokens: String = "2048"
  override protected val requiresApiKey: Boolean = false

  override protected def buildApiUrl(baseUrl: String): Uri = {
    uri"$baseUrl/api/chat"
  }

  override protected def buildHeaders(apiKey: Option[String]): Map[String, String] = {
    Map("Content-Type" -> "application/json")
  }

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
      "messages" -> messages,
      "stream" -> false
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

  override protected def parseProviderResponse(responseBody: String, model: String): ChatResponse = {
    try {
      val parsed = ujson.read(responseBody)

      val id = s"ollama-${System.currentTimeMillis()}"
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

  /**
   * Check if Ollama server is accessible
   */
  def checkServerConnection(): Future[Boolean] = {
    val baseUrl = configStore.get(ConfigStore.OLLAMA_BASE_URL)
      .getOrElse("http://localhost:11434")
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
    val baseUrl = configStore.get(ConfigStore.OLLAMA_BASE_URL)
      .getOrElse("http://localhost:11434")
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
