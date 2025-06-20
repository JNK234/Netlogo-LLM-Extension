package org.nlogo.extensions.llm.models

import upickle.default.{ReadWriter => RW, macroRW}

/**
 * Represents a single message in a chat conversation
 * 
 * @param role The role of the message sender (e.g., "user", "assistant", "system")
 * @param content The text content of the message
 */
case class ChatMessage(role: String, content: String)

object ChatMessage {
  implicit val rw: RW[ChatMessage] = macroRW
  
  /**
   * Create a user message
   */
  def user(content: String): ChatMessage = ChatMessage("user", content)
  
  /**
   * Create an assistant message
   */
  def assistant(content: String): ChatMessage = ChatMessage("assistant", content)
  
  /**
   * Create a system message
   */
  def system(content: String): ChatMessage = ChatMessage("system", content)
}