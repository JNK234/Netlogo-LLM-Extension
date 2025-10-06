package org.nlogo.extensions.llm.config

import scala.io.Source
import scala.util.{Try, Success, Failure}
import java.io.File

/**
 * Utility for loading configuration from key=value format files
 */
object ConfigLoader {

  /**
   * Load configuration from a file with key=value format
   *
   * The file is searched in the following order:
   * 1. Same directory as the NetLogo model file (if available)
   * 2. Exact path as specified
   * 3. Current working directory
   *
   * @param filename Path to the configuration file
   * @param modelDir Optional directory of the currently-open NetLogo model
   * @return Try containing Map of configuration key-value pairs
   */
  def loadFromFile(filename: String, modelDir: Option[String] = None): Try[Map[String, String]] = {
    val possiblePaths = modelDir.map(dir =>
      new File(dir, filename)
    ).toSeq ++ Seq(
      new File(filename),                                    // Exact path as given
      new File(System.getProperty("user.dir"), filename)    // Current working directory
    )

    val file = possiblePaths.find(_.exists()) match {
      case Some(f) => f
      case None =>
        return Failure(new IllegalArgumentException(
          s"Configuration file not found: $filename. Place the file in the same directory as your NetLogo model or in the current working directory."
        ))
    }

    if (!file.canRead()) {
      return Failure(new IllegalArgumentException(s"Cannot read configuration file: ${file.getAbsolutePath}"))
    }

    Try {
      val source = Source.fromFile(file)
      try {
        parseConfigLines(source.getLines().toSeq)
      } finally {
        source.close()
      }
    }.flatten
  }

  /**
   * Parse configuration lines in key=value format
   *
   * @param lines Sequence of configuration lines
   * @return Try containing Map of configuration key-value pairs
   */
  def parseConfigLines(lines: Seq[String]): Try[Map[String, String]] = {
    Try {
      val config = collection.mutable.Map[String, String]()

      lines.zipWithIndex.foreach { case (line, lineNumber) =>
        val trimmedLine = line.trim

        // Skip empty lines and comments (lines starting with #)
        if (trimmedLine.nonEmpty && !trimmedLine.startsWith("#")) {
          parseLine(trimmedLine, lineNumber + 1) match {
            case Success((key, value)) => config(key) = value
            case Failure(e) => throw new IllegalArgumentException(
              s"Error parsing line ${lineNumber + 1}: ${e.getMessage}"
            )
          }
        }
      }

      config.toMap
    }
  }

  /**
   * Parse a single configuration line in key=value format
   *
   * @param line The line to parse
   * @param lineNumber Line number for error reporting
   * @return Try containing (key, value) tuple
   */
  private def parseLine(line: String, lineNumber: Int): Try[(String, String)] = {
    Try {
      val equalIndex = line.indexOf('=')

      if (equalIndex == -1) {
        throw new IllegalArgumentException(s"Missing '=' separator in line: $line")
      }

      if (equalIndex == 0) {
        throw new IllegalArgumentException(s"Missing key in line: $line")
      }

      val key = line.substring(0, equalIndex).trim
      val value = line.substring(equalIndex + 1).trim

      if (key.isEmpty) {
        throw new IllegalArgumentException(s"Empty key in line: $line")
      }

      // Allow empty values
      (key, value)
    }
  }

  /**
   * Validate that required configuration keys are present
   *
   * @param config The configuration map
   * @param requiredKeys Set of required keys
   * @return Try[Unit] - Success if all required keys present, Failure otherwise
   */
  def validateRequiredKeys(config: Map[String, String], requiredKeys: Set[String]): Try[Unit] = {
    val missingKeys = requiredKeys -- config.keySet

    if (missingKeys.nonEmpty) {
      Failure(new IllegalArgumentException(
        s"Missing required configuration keys: ${missingKeys.mkString(", ")}"
      ))
    } else {
      Success(())
    }
  }

  /**
   * Get a configuration value with a default
   *
   * @param config The configuration map
   * @param key The key to look up
   * @param default The default value if key is not found
   * @return The configuration value or default
   */
  def getOrDefault(config: Map[String, String], key: String, default: String): String = {
    config.getOrElse(key, default)
  }
}
