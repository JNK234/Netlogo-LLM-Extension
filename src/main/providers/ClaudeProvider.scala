// ABOUTME: Anthropic Claude provider implementation for Claude models
// ABOUTME: Handles API communication with Anthropic's Claude API using the LLMProvider interface

package org.nlogo.extensions.llm.providers

import org.nlogo.extensions.llm.models.{ChatMessage, ChatRequest, ChatResponse}
import org.nlogo.extensions.llm.config.ConfigStore
import sttp.client3._
import upickle.default.{read, write}
import ujson._
import scala.concurrent.{Future, ExecutionContext}
import scala.util.{Try, Success, Failure}

/**
 * Anthropic Claude provider implementation for Claude models
 */
class ClaudeProvider(implicit ec: ExecutionContext) extends LLMProvider {
  
  private val configStore = new ConfigStore()
  private val backend = HttpClientFutureBackend()
  
  // Set default configuration
  configStore.set(ConfigStore.PROVIDER, "anthropic")
  configStore.set(ConfigStore.MODEL, defaultModel)
  configStore.set(ConfigStore.BASE_URL, "https://api.anthropic.com/v1")
  configStore.set(ConfigStore.TEMPERATURE, ConfigStore.DEFAULT_TEMPERATURE)
  configStore.set(ConfigStore.MAX_TOKENS, "4000")
  
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
      throw new RuntimeException("No response message received from Claude")
    ))
  }
  
  private def sendChatRequest(request: ChatRequest): Future[ChatResponse] = {
    val apiKey = configStore.get(ConfigStore.API_KEY).getOrElse(
      throw new IllegalStateException("API key not configured")
    )
    
    val baseUrl = configStore.getOrElse(ConfigStore.BASE_URL, "https://api.anthropic.com/v1")
    val apiUrl = uri"$baseUrl/messages"
    
    val headers = Map(
      "x-api-key" -> apiKey,
      "content-type" -> "application/json",
      "anthropic-version" -> "2023-06-01"
    )
    
    // Convert our request format to Claude's format
    val claudeRequest = createClaudeRequest(request)
    val requestBody = claudeRequest.toString()
    
    val httpRequest = basicRequest
      .headers(headers)
      .body(requestBody)
      .post(apiUrl)
    
    httpRequest.send(backend).map { response =>
      response.body match {
        case Right(responseBody) =>
          parseClaudeResponse(responseBody, request.model)
        case Left(error) =>
          throw new RuntimeException(s"HTTP request failed: $error")
      }
    }
  }
  
  private def createClaudeRequest(request: ChatRequest): ujson.Value = {
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
  
  private def parseClaudeResponse(responseBody: String, model: String): ChatResponse = {
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
  
  override def providerName: String = "anthropic"
  
  override def defaultModel: String = "claude-3-haiku-20240307"
  
  override def supportsModel(model: String): Boolean = {
    val supportedModels = Set(
      "claude-3-opus-20240229",
      "claude-3-sonnet-20240229", 
      "claude-3-haiku-20240307",
      "claude-3-5-sonnet-20241022"
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
    s"Claude Provider - ${configStore.summary}"
  }
}