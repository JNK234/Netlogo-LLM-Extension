package org.nlogo.extensions.llm

import org.nlogo.api._
import org.nlogo.core.{LogoList, Syntax}
import org.nlogo.extensions.llm.config.{ConfigLoader, ConfigStore}
import org.nlogo.extensions.llm.providers.{LLMProvider, ProviderFactory}
import org.nlogo.extensions.llm.models.ChatMessage
import scala.collection.mutable.{ArrayBuffer, WeakHashMap}
import scala.concurrent.{Await, ExecutionContext, Future}
import scala.concurrent.duration._
import scala.util.{Try, Success, Failure, Random}

/**
 * Main extension class for NetLogo Multi-LLM Extension
 * 
 * This extension provides a unified interface for multiple LLM providers
 * including OpenAI, Anthropic, Gemini, and Ollama.
 */
class LLMExtension extends DefaultClassManager {
  
  // Global configuration store
  private val configStore = ConfigStore.withDefaults()
  
  // Current provider instance
  private var currentProvider: Option[LLMProvider] = None
  
  // Per-agent conversation history
  private val messageHistory: WeakHashMap[Agent, ArrayBuffer[ChatMessage]] = WeakHashMap()
  
  // Execution context for async operations
  implicit private val ec: ExecutionContext = ExecutionContext.global
  
  /**
   * Create an AwaitableReporter that wraps a Future to provide truly async behavior
   * The Future starts immediately but execution defers until runresult is called
   */
  private def createAwaitableReporter(future: Future[String]): AnonymousReporter = {
    new AnonymousReporter {
      override def syntax: Syntax = Syntax.reporterSyntax(right = List(), ret = Syntax.StringType)
      
      override def report(context: Context, args: Array[AnyRef]): AnyRef = {
        val timeoutSeconds = try {
          configStore.getOrElse(ConfigStore.TIMEOUT_SECONDS, ConfigStore.DEFAULT_TIMEOUT_SECONDS).toInt
        } catch {
          case _: NumberFormatException => 30
        }
        
        try {
          Await.result(future, timeoutSeconds.seconds)
        } catch {
          case e: Exception =>
            throw new ExtensionException(s"Async LLM operation failed: ${e.getMessage}")
        }
      }
    }
  }
  
  /**
   * Called when the extension is loaded to register primitives
   */
  override def load(manager: PrimitiveManager): Unit = {
    // Configuration primitives
    manager.addPrimitive("set-provider", SetProviderCommand)
    manager.addPrimitive("set-api-key", SetApiKeyCommand)
    manager.addPrimitive("set-model", SetModelCommand)
    manager.addPrimitive("load-config", LoadConfigCommand)
    
    // Core chat primitives
    manager.addPrimitive("chat", ChatReporter)
    manager.addPrimitive("chat-async", ChatAsyncReporter)
    manager.addPrimitive("choose", ChooseReporter)
    
    // History management primitives
    manager.addPrimitive("history", HistoryReporter)
    manager.addPrimitive("set-history", SetHistoryCommand)
    manager.addPrimitive("clear-history", ClearHistoryCommand)
  }
  
  /**
   * Called when NetLogo calls clear-all or when the model is reset
   */
  override def clearAll(): Unit = {
    messageHistory.clear()
  }
  
  /**
   * Initialize or update the current provider based on configuration
   */
  private def ensureProvider(): LLMProvider = {
    currentProvider match {
      case Some(provider) => provider
      case None =>
        ProviderFactory.createProviderFromConfig(configStore) match {
          case Success(provider) =>
            currentProvider = Some(provider)
            provider
          case Failure(e) =>
            throw new ExtensionException(s"Failed to initialize LLM provider: ${e.getMessage}")
        }
    }
  }
  
  /**
   * Get or create conversation history for an agent
   */
  private def getAgentHistory(agent: Agent): ArrayBuffer[ChatMessage] = {
    messageHistory.getOrElseUpdate(agent, ArrayBuffer.empty[ChatMessage])
  }
  
  // Configuration Commands
  
  object SetProviderCommand extends Command {
    override def getSyntax: Syntax = Syntax.commandSyntax(right = List(Syntax.StringType))
    
    override def perform(args: Array[Argument], context: Context): Unit = {
      val providerName = args(0).getString
      configStore.set(ConfigStore.PROVIDER, providerName)
      currentProvider = None // Force re-initialization with new provider
    }
  }
  
  object SetApiKeyCommand extends Command {
    override def getSyntax: Syntax = Syntax.commandSyntax(right = List(Syntax.StringType))
    
    override def perform(args: Array[Argument], context: Context): Unit = {
      val apiKey = args(0).getString
      configStore.set(ConfigStore.API_KEY, apiKey)
      currentProvider.foreach(_.setConfig(ConfigStore.API_KEY, apiKey))
    }
  }
  
  object SetModelCommand extends Command {
    override def getSyntax: Syntax = Syntax.commandSyntax(right = List(Syntax.StringType))
    
    override def perform(args: Array[Argument], context: Context): Unit = {
      val model = args(0).getString
      configStore.set(ConfigStore.MODEL, model)
      currentProvider.foreach(_.setConfig(ConfigStore.MODEL, model))
    }
  }
  
  object LoadConfigCommand extends Command {
    override def getSyntax: Syntax = Syntax.commandSyntax(right = List(Syntax.StringType))
    
    override def perform(args: Array[Argument], context: Context): Unit = {
      val filename = args(0).getString
      
      ConfigLoader.loadFromFile(filename) match {
        case Success(config) =>
          configStore.loadFromMap(config)
          currentProvider = None // Force re-initialization with new config
        case Failure(e) =>
          throw new ExtensionException(s"Failed to load configuration from '$filename': ${e.getMessage}")
      }
    }
  }
  
  // Chat Primitives
  
  object ChatReporter extends Reporter {
    override def getSyntax: Syntax = Syntax.reporterSyntax(
      right = List(Syntax.StringType),
      ret = Syntax.StringType
    )
    
    override def report(args: Array[Argument], context: Context): AnyRef = {
      val inputText = args(0).getString
      val agent = context.getAgent
      
      try {
        val provider = ensureProvider()
        val history = getAgentHistory(agent)
        
        // Add user message to history
        val userMessage = ChatMessage.user(inputText)
        history += userMessage
        
        // Send chat request
        val responseFuture = provider.chat(history.toSeq)
        val responseMessage = Await.result(responseFuture, 30.seconds)
        
        // Add response to history
        history += responseMessage
        
        responseMessage.content
        
      } catch {
        case e: Exception =>
          throw new ExtensionException(s"LLM chat failed: ${e.getMessage}")
      }
    }
  }
  
  object ChatAsyncReporter extends Reporter {
    override def getSyntax: Syntax = Syntax.reporterSyntax(
      right = List(Syntax.StringType),
      ret = Syntax.ReporterType
    )
    
    override def report(args: Array[Argument], context: Context): AnyRef = {
      val inputText = args(0).getString
      val agent = context.getAgent
      
      try {
        val provider = ensureProvider()
        val history = getAgentHistory(agent)
        
        // Add user message to history immediately
        val userMessage = ChatMessage.user(inputText)
        history += userMessage
        
        // Start the Future immediately but defer execution until runresult
        val responseFuture = provider.chat(history.toSeq).map { responseMessage =>
          // Add response to history when completed
          history += responseMessage
          responseMessage.content
        }
        
        // Return AnonymousReporter that wraps the Future
        createAwaitableReporter(responseFuture)
        
      } catch {
        case e: Exception =>
          throw new ExtensionException(s"Failed to start async LLM chat: ${e.getMessage}")
      }
    }
  }
  
  object ChooseReporter extends Reporter {
    override def getSyntax: Syntax = Syntax.reporterSyntax(
      right = List(Syntax.StringType, Syntax.ListType),
      ret = Syntax.StringType
    )
    
    override def report(args: Array[Argument], context: Context): AnyRef = {
      val prompt = args(0).getString
      val choicesList = args(1).getList
      val agent = context.getAgent
      
      try {
        val provider = ensureProvider()
        val history = getAgentHistory(agent)
        
        // Convert LogoList to Scala list of strings
        val choices = choicesList.map(_.toString).toList
        
        if (choices.isEmpty) {
          throw new ExtensionException("Choice list cannot be empty")
        }
        
        // Create constrained prompt that forces selection from choices
        val constrainedPrompt = s"""$prompt
        
You must respond with EXACTLY ONE of the following options (no other text):
${choices.zipWithIndex.map { case (choice, idx) => s"${idx + 1}. $choice" }.mkString("\n")}

Response:"""
        
        // Add user message to history
        val userMessage = ChatMessage.user(constrainedPrompt)
        history += userMessage
        
        // Send chat request
        val responseFuture = provider.chat(history.toSeq)
        val responseMessage = Await.result(responseFuture, {
          val timeoutSeconds = try {
            configStore.getOrElse(ConfigStore.TIMEOUT_SECONDS, ConfigStore.DEFAULT_TIMEOUT_SECONDS).toInt
          } catch {
            case _: NumberFormatException => 30
          }
          timeoutSeconds.seconds
        })
        
        // Add response to history
        history += responseMessage
        
        // Extract the chosen option from response
        val response = responseMessage.content.trim
        
        // Try to match response to one of the choices
        val chosenOption = choices.find { choice =>
          response.toLowerCase.contains(choice.toLowerCase) ||
          choice.toLowerCase.contains(response.toLowerCase)
        }.orElse {
          // Try to match by number (1, 2, 3, etc.)
          try {
            val number = response.replaceAll("[^\\d]", "").toInt
            if (number >= 1 && number <= choices.length) {
              Some(choices(number - 1))
            } else None
          } catch {
            case _: NumberFormatException => None
          }
        }.getOrElse {
          // Fallback: return random choice if no match found
          val randomIndex = Random.nextInt(choices.length)
          choices(randomIndex)
        }
        
        chosenOption
        
      } catch {
        case e: ExtensionException => throw e
        case e: Exception =>
          throw new ExtensionException(s"LLM choice failed: ${e.getMessage}")
      }
    }
  }
  
  // History Management Primitives
  
  object HistoryReporter extends Reporter {
    override def getSyntax: Syntax = Syntax.reporterSyntax(ret = Syntax.ListType)
    
    override def report(args: Array[Argument], context: Context): LogoList = {
      val agent = context.getAgent
      val history = getAgentHistory(agent)
      
      LogoList.fromIterator(
        history.map { message =>
          LogoList(message.role, message.content)
        }.iterator
      )
    }
  }
  
  object SetHistoryCommand extends Command {
    override def getSyntax: Syntax = Syntax.commandSyntax(right = List(Syntax.ListType))
    
    override def perform(args: Array[Argument], context: Context): Unit = {
      val agent = context.getAgent
      val historyList = args(0).getList
      
      try {
        val messages = historyList.map {
          case l: LogoList if l.size == 2 =>
            ChatMessage(l(0).toString, l(1).toString)
          case _ =>
            throw new ExtensionException("History items must be lists of [role content] pairs")
        }.to[ArrayBuffer]
        
        messageHistory.put(agent, messages)
        
      } catch {
        case e: ExtensionException => throw e
        case e: Exception =>
          throw new ExtensionException(s"Invalid history format: ${e.getMessage}")
      }
    }
  }
  
  object ClearHistoryCommand extends Command {
    override def getSyntax: Syntax = Syntax.commandSyntax()
    
    override def perform(args: Array[Argument], context: Context): Unit = {
      val agent = context.getAgent
      messageHistory.remove(agent)
    }
  }
}