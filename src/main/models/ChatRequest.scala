package org.nlogo.extensions.llm.models

import upickle.default.{ReadWriter => RW, macroRW}

/**
 * Represents a chat completion request to an LLM provider
 *
 * @param model The model identifier (e.g., "gpt-4", "claude-3-sonnet")
 * @param messages The conversation history as a sequence of messages
 * @param maxTokens Optional maximum number of tokens to generate
 * @param temperature Optional temperature for response randomness (0.0-2.0)
 */
case class ChatRequest(
  model: String,
  messages: Seq[ChatMessage],
  maxTokens: Option[Int] = None,
  temperature: Option[Double] = None
)

object ChatRequest {
  implicit val rw: RW[ChatRequest] = macroRW

  /**
   * Create a simple request with just model and messages
   */
  def simple(model: String, messages: Seq[ChatMessage]): ChatRequest = {
    ChatRequest(model, messages)
  }

  /**
   * Create a request with temperature control
   */
  def withTemperature(model: String, messages: Seq[ChatMessage], temperature: Double): ChatRequest = {
    ChatRequest(model, messages, temperature = Some(temperature))
  }
}
