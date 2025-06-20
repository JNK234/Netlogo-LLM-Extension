package org.nlogo.extensions.llm.models

import upickle.default.{ReadWriter => RW, macroRW}

/**
 * Represents a response choice from an LLM provider
 * 
 * @param index The index of this choice (usually 0 for single responses)
 * @param message The message content of the response
 * @param finishReason The reason the response ended (e.g., "stop", "length")
 */
case class Choice(
  index: Int,
  message: ChatMessage,
  finishReason: String
)

object Choice {
  implicit val rw: RW[Choice] = macroRW
}

/**
 * Represents a complete chat response from an LLM provider
 * 
 * @param id Unique identifier for this response
 * @param created Timestamp when the response was created
 * @param model The model that generated the response
 * @param choices Array of response choices (usually contains one choice)
 */
case class ChatResponse(
  id: String,
  created: Long,
  model: String,
  choices: Array[Choice]
) {
  /**
   * Get the first (and usually only) response message
   */
  def firstMessage: Option[ChatMessage] = {
    choices.headOption.map(_.message)
  }
  
  /**
   * Get the content of the first response message
   */
  def firstContent: Option[String] = {
    firstMessage.map(_.content)
  }
}

object ChatResponse {
  implicit val rw: RW[ChatResponse] = macroRW
  
  /**
   * Create a simple response with a single message
   */
  def simple(id: String, model: String, message: ChatMessage): ChatResponse = {
    ChatResponse(
      id = id,
      created = System.currentTimeMillis() / 1000,
      model = model,
      choices = Array(Choice(0, message, "stop"))
    )
  }
}