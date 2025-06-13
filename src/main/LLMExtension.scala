package org.nlogo.extensions.llm

import org.nlogo.api._
import org.nlogo.core.{LogoList, Syntax}
import org.nlogo.extensions.llm.config.{ConfigLoader, ConfigStore}
import org.nlogo.extensions.llm.providers.{LLMProvider, ProviderFactory}
import org.nlogo.extensions.llm.models.ChatMessage
import scala.collection.mutable.{ArrayBuffer, WeakHashMap}
import scala.concurrent.{Await, ExecutionContext, Future}
import scala.concurrent.duration._
import scala.util.{Try, Success, Failure}

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
        
        // Add user message to history
        val userMessage = ChatMessage.user(inputText)
        history += userMessage
        
        // Create anonymous reporter that will return the result when called
        new AnonymousReporter {
          override def syntax: Syntax = Syntax.reporterSyntax(right = List(), ret = Syntax.StringType)
          
          override def report(c: Context, args: Array[AnyRef]): AnyRef = {
            try {
              val responseFuture = provider.chat(history.toSeq)
              val responseMessage = Await.result(responseFuture, 30.seconds)
              
              // Add response to history
              history += responseMessage
              
              responseMessage.content
            } catch {
              case e: Exception =>
                throw new ExtensionException(s"Async LLM chat failed: ${e.getMessage}")
            }
          }
        }
        
      } catch {
        case e: Exception =>
          throw new ExtensionException(s"Failed to start async LLM chat: ${e.getMessage}")
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