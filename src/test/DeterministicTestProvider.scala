package org.nlogo.extensions.llm.providers

import org.nlogo.extensions.llm.config.ConfigStore
import org.nlogo.extensions.llm.models.{ChatMessage, ChatRequest, ChatResponse}
import scala.concurrent.{ExecutionContext, Future}
import scala.util.{Success, Try}

/**
 * Deterministic provider used only by tests.
 *
 * It avoids external API/network calls and returns predictable outputs
 * based on the latest user message.
 */
class DeterministicTestProvider(implicit ec: ExecutionContext) extends LLMProvider {
  private val configStore = new ConfigStore()
  private val firstChoiceRegex = """(?m)^\s*1\.\s*(.+?)\s*$""".r

  override def chat(request: ChatRequest): Future[ChatResponse] = {
    chat(request.messages).map { message =>
      ChatResponse.simple(
        id = "deterministic-test-response",
        model = request.model,
        message = message
      )
    }
  }

  override def chat(messages: Seq[ChatMessage]): Future[ChatMessage] = Future.successful {
    val lastUserMessage = messages.reverseIterator
      .find(_.role == "user")
      .map(_.content)
      .getOrElse("")

    val content = if (lastUserMessage.contains("You must respond with EXACTLY ONE")) {
      firstChoiceRegex.findFirstMatchIn(lastUserMessage).map(_.group(1).trim).getOrElse("1")
    } else {
      s"stub:$lastUserMessage"
    }

    ChatMessage.assistant(content)
  }

  override def setConfig(key: String, value: String): Unit = {
    configStore.set(key, value)
  }

  override def getConfig(key: String): Option[String] = {
    configStore.get(key)
  }

  override def validateConfig(): Try[Unit] = Success(())

  override def providerName: String = "deterministic-test"

  override def defaultModel: String = "deterministic-model"

  override def supportsModel(model: String): Boolean = true
}
