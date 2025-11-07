package org.nlogo.extensions.llm

import org.nlogo.api._
import org.nlogo.core.{LogoList, Syntax}
import org.nlogo.extensions.llm.config.{ConfigLoader, ConfigStore}
import org.nlogo.extensions.llm.providers.{LLMProvider, ProviderFactory, ModelRegistry, OllamaProvider}
import org.nlogo.extensions.llm.models.ChatMessage
import scala.collection.mutable.{ArrayBuffer, WeakHashMap}
import scala.concurrent.{Await, ExecutionContext, Future}
import scala.concurrent.duration._
import scala.util.{Try, Success, Failure, Random}
import scala.jdk.CollectionConverters._
import io.circe.yaml.parser
import io.circe.{Json, HCursor}
import java.nio.file.{Files, Paths}
import java.nio.charset.StandardCharsets

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
    manager.addPrimitive("chat-with-template", ChatWithTemplateReporter)
    manager.addPrimitive("choose", ChooseReporter)
    
    // History management primitives
    manager.addPrimitive("history", HistoryReporter)
    manager.addPrimitive("set-history", SetHistoryCommand)
    manager.addPrimitive("clear-history", ClearHistoryCommand)
    
    // Provider information primitives
    manager.addPrimitive("providers", ProvidersReporter)
    manager.addPrimitive("providers-all", ProvidersAllReporter)
    manager.addPrimitive("provider-status", ProviderStatusReporter)
    manager.addPrimitive("provider-help", ProviderHelpReporter)
    manager.addPrimitive("models", ModelsReporter)
    manager.addPrimitive("active", ActiveReporter)
    manager.addPrimitive("config", ConfigReporter)
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
  
  /**
   * Check if a provider has an API key configured
   */
  private def hasApiKey(providerName: String): Boolean = {
    val providerKeyName = ConfigStore.getProviderApiKeyName(providerName)
    configStore.get(providerKeyName).orElse(configStore.get(ConfigStore.API_KEY)) match {
      case Some(key) => key.trim.nonEmpty
      case None => false
    }
  }
  
  /**
   * Check if Ollama is reachable (synchronous with short timeout)
   */
  private def isOllamaReachable: Boolean = {
    try {
      val provider = new OllamaProvider()
      val baseUrl = configStore.get(ConfigStore.OLLAMA_BASE_URL)
        .orElse(configStore.get(ConfigStore.BASE_URL))
        .getOrElse(ConfigStore.DEFAULT_OLLAMA_BASE_URL)
      provider.setConfig(ConfigStore.BASE_URL, baseUrl)
      
      val checkFuture = provider.checkServerConnection()
      Await.result(checkFuture, 1.second)
    } catch {
      case _: Exception => false
    }
  }
  
  /**
   * Check if a provider is ready to use
   */
  private def isProviderReady(providerName: String): Boolean = {
    providerName.toLowerCase.trim match {
      case "ollama" => isOllamaReachable
      case "openai" | "anthropic" | "gemini" => hasApiKey(providerName)
      case _ => false
    }
  }
  
  /**
   * Case class for YAML template structure
   */
  case class Template(system: String, template: String)
  
  /**
   * Load a YAML template file and parse it
   *
   * @param filename Path to the template file
   * @param modelDir Optional directory of the currently-open NetLogo model
   */
  private def loadTemplate(filename: String, modelDir: Option[String] = None): Try[Template] = {
    Try {
      val possiblePaths = modelDir.map(dir =>
        Paths.get(dir, filename)
      ).toSeq ++ Seq(
        Paths.get(filename),
        Paths.get(System.getProperty("user.dir"), filename)
      )

      val path = possiblePaths.find(Files.exists(_)).getOrElse {
        throw new IllegalArgumentException(
          s"Template file not found: $filename. Place the file in the same directory as your NetLogo model or in the current working directory."
        )
      }

      val content = Files.readString(path, StandardCharsets.UTF_8)
      parser.parse(content) match {
        case Right(json) =>
          val cursor: HCursor = json.hcursor
          val system = cursor.downField("system").as[String].getOrElse("")
          val template = cursor.downField("template").as[String].getOrElse("")
          Template(system, template)
        case Left(error) =>
          throw new RuntimeException(s"Failed to parse YAML: ${error.getMessage}")
      }
    }
  }
  
  /**
   * Substitute variables in a template string
   */
  private def substituteVariables(template: String, variables: Map[String, String]): String = {
    variables.foldLeft(template) { case (text, (key, value)) =>
      text.replace(s"{$key}", value)
    }
  }
  
  /**
   * Convert NetLogo variable list to Scala Map
   */
  private def parseVariables(variablesList: LogoList): Map[String, String] = {
    variablesList.map {
      case varList: LogoList if varList.size == 2 =>
        varList(0).toString -> varList(1).toString
      case _ =>
        throw new ExtensionException("Variables must be lists of [key value] pairs")
    }.toMap
  }
  
  // Configuration Commands
  
  object SetProviderCommand extends Command {
    override def getSyntax: Syntax = Syntax.commandSyntax(right = List(Syntax.StringType))
    
    override def perform(args: Array[Argument], context: Context): Unit = {
      val providerName = args(0).getString.toLowerCase.trim
      
      // Check if provider is supported
      if (!ProviderFactory.isSupported(providerName)) {
        throw new ExtensionException(
          s"Unknown provider: '$providerName'. Supported providers: ${ProviderFactory.getSupportedProviders.mkString(", ")}"
        )
      }
      
      // Apply provider defaults
      val defaults = ProviderFactory.getDefaultConfig(providerName)
      defaults.foreach { case (key, value) =>
        if (!configStore.contains(key) || key == ConfigStore.MODEL) {
          configStore.set(key, value)
        }
      }
      
      // Set provider
      configStore.set(ConfigStore.PROVIDER, providerName)
      
      // Validate immediately
      providerName match {
        case "ollama" =>
          if (!isOllamaReachable) {
            val baseUrl = configStore.get(ConfigStore.OLLAMA_BASE_URL)
              .orElse(configStore.get(ConfigStore.BASE_URL))
              .getOrElse(ConfigStore.DEFAULT_OLLAMA_BASE_URL)
            throw new ExtensionException(
              s"Ollama not reachable at $baseUrl. Please start Ollama server or change ollama_base_url. For help: print llm:provider-help \"ollama\""
            )
          }
        case _ =>
          if (!hasApiKey(providerName)) {
            val keyName = ConfigStore.getProviderApiKeyName(providerName)
            throw new ExtensionException(
              s"$providerName provider requires an API key. Set '$keyName' in config or call llm:set-api-key. For help: print llm:provider-help \"$providerName\""
            )
          }
      }
      
      // Force re-initialization with new provider
      currentProvider = None
    }
  }
  
  object SetApiKeyCommand extends Command {
    override def getSyntax: Syntax = Syntax.commandSyntax(right = List(Syntax.StringType))
    
    override def perform(args: Array[Argument], context: Context): Unit = {
      val apiKey = args(0).getString
      val currentProviderName = configStore.getOrElse(ConfigStore.PROVIDER, ConfigStore.DEFAULT_PROVIDER)
      
      // Store in both provider-specific key and generic key (for backwards compatibility)
      val providerKeyName = ConfigStore.getProviderApiKeyName(currentProviderName)
      configStore.set(providerKeyName, apiKey)
      configStore.set(ConfigStore.API_KEY, apiKey)
      
      // Update current provider if initialized
      currentProvider.foreach(_.setConfig(ConfigStore.API_KEY, apiKey))
    }
  }
  
  object SetModelCommand extends Command {
    override def getSyntax: Syntax = Syntax.commandSyntax(right = List(Syntax.StringType))
    
    override def perform(args: Array[Argument], context: Context): Unit = {
      val model = args(0).getString
      val providerName = configStore.getOrElse(ConfigStore.PROVIDER, ConfigStore.DEFAULT_PROVIDER)
      
      // Validate model against current provider
      if (!ModelRegistry.isValidModel(providerName, model)) {
        throw new ExtensionException(
          s"Unsupported model '$model' for provider '$providerName'. Supported models: ${ModelRegistry.getModelListForDisplay(providerName)}. Use llm:models to see all available models."
        )
      }
      
      configStore.set(ConfigStore.MODEL, model)
      currentProvider.foreach(_.setConfig(ConfigStore.MODEL, model))
    }
  }
  
  object LoadConfigCommand extends Command {
    override def getSyntax: Syntax = Syntax.commandSyntax(right = List(Syntax.StringType))

    override def perform(args: Array[Argument], context: Context): Unit = {
      val filename = args(0).getString

      // Extract model directory from workspace
      val modelDir = Option(context.workspace.getModelPath).flatMap { path =>
        Option(new java.io.File(path).getParent)
      }

      ConfigLoader.loadFromFile(filename, modelDir) match {
        case Success(config) =>
          configStore.loadFromMap(config)
          
          // Validate provider after loading config
          val providerName = configStore.getOrElse(ConfigStore.PROVIDER, ConfigStore.DEFAULT_PROVIDER)
          providerName.toLowerCase.trim match {
            case "ollama" =>
              if (!isOllamaReachable) {
                val baseUrl = configStore.get(ConfigStore.OLLAMA_BASE_URL)
                  .orElse(configStore.get(ConfigStore.BASE_URL))
                  .getOrElse(ConfigStore.DEFAULT_OLLAMA_BASE_URL)
                throw new ExtensionException(
                  s"Config loaded but Ollama not reachable at $baseUrl. Please start Ollama server or change ollama_base_url in config. For help: print llm:provider-help \"ollama\""
                )
              }
            case _ =>
              if (!hasApiKey(providerName)) {
                val keyName = ConfigStore.getProviderApiKeyName(providerName)
                throw new ExtensionException(
                  s"Config loaded but $providerName provider requires an API key. Set '$keyName' in config. For help: print llm:provider-help \"$providerName\""
                )
              }
          }
          
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
  
  object ChatWithTemplateReporter extends Reporter {
    override def getSyntax: Syntax = Syntax.reporterSyntax(
      right = List(Syntax.StringType, Syntax.ListType),
      ret = Syntax.StringType
    )

    override def report(args: Array[Argument], context: Context): AnyRef = {
      val templateFile = args(0).getString
      val variablesList = args(1).getList
      val agent = context.getAgent

      try {
        val provider = ensureProvider()
        val history = getAgentHistory(agent)

        // Extract model directory from workspace
        val modelDir = Option(context.workspace.getModelPath).flatMap { path =>
          Option(new java.io.File(path).getParent)
        }

        // Load and parse template
        val template = loadTemplate(templateFile, modelDir) match {
          case Success(t) => t
          case Failure(e) => throw new ExtensionException(s"Failed to load template '$templateFile': ${e.getMessage}")
        }
        
        // Parse variables from NetLogo list
        val variables = parseVariables(variablesList)
        
        // Substitute variables in template
        val processedTemplate = substituteVariables(template.template, variables)
        
        // Create a temporary history with system message if provided
        val tempHistory = if (template.system.nonEmpty) {
          ArrayBuffer(ChatMessage.system(template.system)) ++ history
        } else {
          history
        }
        
        // Add user message with processed template
        val userMessage = ChatMessage.user(processedTemplate)
        tempHistory += userMessage
        
        // Send chat request
        val responseFuture = provider.chat(tempHistory.toSeq)
        val responseMessage = Await.result(responseFuture, 30.seconds)
        
        // Add both template message and response to permanent history
        history += userMessage
        history += responseMessage
        
        responseMessage.content
        
      } catch {
        case e: ExtensionException => throw e
        case e: Exception =>
          throw new ExtensionException(s"Template chat failed: ${e.getMessage}")
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

// TODO: CHECK if the Generated output is only from the provided list.
        
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
        }.to(ArrayBuffer)
        
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
  
  // Provider Information Reporters
  
  object ProvidersReporter extends Reporter {
    override def getSyntax: Syntax = Syntax.reporterSyntax(ret = Syntax.ListType)
    
    override def report(args: Array[Argument], context: Context): AnyRef = {
      try {
        // Return only READY providers
        val readyProviders = ProviderFactory.getSupportedProviders
          .filter(isProviderReady)
          .toList
          .sorted
        LogoList.fromJava(readyProviders.asJava)
      } catch {
        case e: Exception =>
          throw new ExtensionException(s"Failed to get ready providers: ${e.getMessage}")
      }
    }
  }
  
  object ProvidersAllReporter extends Reporter {
    override def getSyntax: Syntax = Syntax.reporterSyntax(ret = Syntax.ListType)
    
    override def report(args: Array[Argument], context: Context): AnyRef = {
      try {
        val allProviders = ProviderFactory.getSupportedProviders.toList.sorted
        LogoList.fromJava(allProviders.asJava)
      } catch {
        case e: Exception =>
          throw new ExtensionException(s"Failed to get all providers: ${e.getMessage}")
      }
    }
  }
  
  object ProviderStatusReporter extends Reporter {
    override def getSyntax: Syntax = Syntax.reporterSyntax(ret = Syntax.ListType)
    
    override def report(args: Array[Argument], context: Context): AnyRef = {
      try {
        val statusList = ProviderFactory.getSupportedProviders.toList.sorted.map { provider =>
          val ready = isProviderReady(provider)
          
          val details = provider.toLowerCase.trim match {
            case "ollama" =>
              val baseUrl = configStore.get(ConfigStore.OLLAMA_BASE_URL)
                .orElse(configStore.get(ConfigStore.BASE_URL))
                .getOrElse(ConfigStore.DEFAULT_OLLAMA_BASE_URL)
              LogoList(
                provider,
                LogoList("ready", Boolean.box(ready)),
                LogoList("reachable", Boolean.box(ready)),
                LogoList("base-url", baseUrl)
              )
            case _ =>
              val hasKey = hasApiKey(provider)
              LogoList(
                provider,
                LogoList("ready", Boolean.box(ready)),
                LogoList("has-key", Boolean.box(hasKey))
              )
          }
          details
        }
        
        LogoList.fromJava(statusList.asJava)
      } catch {
        case e: Exception =>
          throw new ExtensionException(s"Failed to get provider status: ${e.getMessage}")
      }
    }
  }
  
  object ProviderHelpReporter extends Reporter {
    override def getSyntax: Syntax = Syntax.reporterSyntax(
      right = List(Syntax.StringType),
      ret = Syntax.StringType
    )
    
    override def report(args: Array[Argument], context: Context): AnyRef = {
      val providerName = args(0).getString.toLowerCase.trim
      
      providerName match {
        case "ollama" =>
          """Ollama Setup Instructions:
            |
            |1. Install Ollama:
            |   - Visit https://ollama.ai/download
            |   - Download and install for your platform
            |
            |2. Start Ollama server:
            |   - Open terminal and run: ollama serve
            |   - Or start Ollama app (it runs in background)
            |
            |3. Pull a model:
            |   - Run: ollama pull llama3.2
            |   - Or try: ollama pull deepseek-r1:1.5b (smaller)
            |
            |4. Verify installation:
            |   - Check llm:provider-status for "reachable: true"
            |
            |5. Custom server URL:
            |   - In config: ollama_base_url=http://your-server:11434
            |   - Default: http://localhost:11434
            |
            |For more models: ollama.ai/library""".stripMargin
        
        case "openai" =>
          s"""OpenAI Setup Instructions:
            |
            |1. Get an API key:
            |   - Visit https://platform.openai.com/api-keys
            |   - Create a new API key
            |
            |2. Set the key:
            |   - In config file: ${ConfigStore.OPENAI_API_KEY}=sk-your-key-here
            |   - Or at runtime: llm:set-api-key "sk-your-key-here"
            |
            |3. Verify:
            |   - Check llm:provider-status for "has-key: true"""".stripMargin
        
        case "anthropic" =>
          s"""Anthropic (Claude) Setup Instructions:
            |
            |1. Get an API key:
            |   - Visit https://console.anthropic.com/
            |   - Create a new API key
            |
            |2. Set the key:
            |   - In config file: ${ConfigStore.ANTHROPIC_API_KEY}=sk-ant-your-key-here
            |   - Or at runtime: llm:set-api-key "sk-ant-your-key-here"
            |
            |3. Verify:
            |   - Check llm:provider-status for "has-key: true"""".stripMargin
        
        case "gemini" =>
          s"""Google Gemini Setup Instructions:
            |
            |1. Get an API key:
            |   - Visit https://makersuite.google.com/app/apikey
            |   - Create a new API key
            |
            |2. Set the key:
            |   - In config file: ${ConfigStore.GEMINI_API_KEY}=your-key-here
            |   - Or at runtime: llm:set-api-key "your-key-here"
            |
            |3. Verify:
            |   - Check llm:provider-status for "has-key: true"""".stripMargin
        
        case _ =>
          s"Unknown provider: $providerName. Supported providers: ${ProviderFactory.getSupportedProviders.mkString(", ")}"
      }
    }
  }
  
  object ActiveReporter extends Reporter {
    override def getSyntax: Syntax = Syntax.reporterSyntax(ret = Syntax.ListType)
    
    override def report(args: Array[Argument], context: Context): AnyRef = {
      try {
        val provider = configStore.getOrElse(ConfigStore.PROVIDER, ConfigStore.DEFAULT_PROVIDER)
        val model = configStore.getOrElse(ConfigStore.MODEL, ModelRegistry.defaultModel(provider))
        LogoList(provider, model)
      } catch {
        case e: Exception =>
          throw new ExtensionException(s"Failed to get active configuration: ${e.getMessage}")
      }
    }
  }
  
  object ConfigReporter extends Reporter {
    override def getSyntax: Syntax = Syntax.reporterSyntax(ret = Syntax.StringType)
    
    override def report(args: Array[Argument], context: Context): AnyRef = {
      try {
        configStore.summary
      } catch {
        case e: Exception =>
          throw new ExtensionException(s"Failed to get config summary: ${e.getMessage}")
      }
    }
  }
  
  object ModelsReporter extends Reporter {
    override def getSyntax: Syntax = Syntax.reporterSyntax(ret = Syntax.ListType)
    
    override def report(args: Array[Argument], context: Context): AnyRef = {
      try {
        val providerName = configStore.getOrElse(ConfigStore.PROVIDER, ConfigStore.DEFAULT_PROVIDER)
        
        // For Ollama, try to fetch installed models if reachable
        val supportedModels = if (providerName.toLowerCase.trim == "ollama") {
          try {
            currentProvider match {
              case Some(provider: OllamaProvider) =>
                // Try to get installed models with a short timeout
                val installedFuture = provider.listInstalledModels()
                val installed = Await.result(installedFuture, 2.seconds)
                
                if (installed.nonEmpty) {
                  installed
                } else {
                  // Fallback to curated list if empty
                  ModelRegistry.getSupportedModels("ollama")
                }
              case _ =>
                // Provider not initialized yet, use curated list
                ModelRegistry.getSupportedModels("ollama")
            }
          } catch {
            case _: Exception =>
              // If fetching fails, use curated list
              ModelRegistry.getSupportedModels("ollama")
          }
        } else {
          // For non-Ollama providers, use ModelRegistry
          ModelRegistry.getSupportedModels(providerName)
        }
        
        val modelList = supportedModels.toList.sorted
        LogoList.fromJava(modelList.asJava)
      } catch {
        case e: Exception =>
          throw new ExtensionException(s"Failed to get supported models: ${e.getMessage}")
      }
    }
  }
}