package org.nlogo.extensions.llm

import org.nlogo.api.{DefaultClassManager, PrimitiveManager}

/**
 * Main extension class for NetLogo Multi-LLM Extension
 * 
 * This extension provides a unified interface for multiple LLM providers
 * including OpenAI, Anthropic, Gemini, and Ollama.
 */
class LLMExtension extends DefaultClassManager {
  
  /**
   * Called when the extension is loaded to register primitives
   */
  override def load(manager: PrimitiveManager): Unit = {
    // Primitives will be registered here in later steps
  }
  
  /**
   * Called when NetLogo calls clear-all or when the model is reset
   */
  override def clearAll(): Unit = {
    // Clear extension state here in later steps
  }
}