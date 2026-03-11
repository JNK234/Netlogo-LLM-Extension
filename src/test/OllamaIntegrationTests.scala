// ABOUTME: Integration tests that run against a real local Ollama server
// ABOUTME: Skipped automatically when Ollama is not reachable (e.g. CI)

package org.nlogo.extensions.llm

import org.scalatest.BeforeAndAfterAll

import java.io.File
import java.net.{HttpURLConnection, URL}
import org.nlogo.headless.TestLanguage

object OllamaIntegrationTests {
  val testFileNames = Seq("tests-ollama.txt")
  val testFiles     = testFileNames.map( (f) => (new File(f)).getCanonicalFile )

  def isOllamaReachable: Boolean = {
    try {
      val url = new URL("http://localhost:11434/api/tags")
      val conn = url.openConnection().asInstanceOf[HttpURLConnection]
      conn.setConnectTimeout(2000)
      conn.setReadTimeout(2000)
      conn.setRequestMethod("GET")
      val code = conn.getResponseCode
      conn.disconnect()
      code == 200
    } catch {
      case _: Exception => false
    }
  }
}

class OllamaIntegrationTests extends TestLanguage(OllamaIntegrationTests.testFiles) with BeforeAndAfterAll {
  System.setProperty("org.nlogo.preferHeadless", "true")

  override def beforeAll(): Unit = {
    if (!OllamaIntegrationTests.isOllamaReachable) {
      cancel("Ollama not reachable at localhost:11434 — skipping integration tests")
    }
    super.beforeAll()
  }

  override def afterAll(): Unit = {
    val file = new File("tmp/llm")
    def deleteRec(f: File): Unit = {
      if (f.isDirectory) {
        f.listFiles().foreach(deleteRec)
      }
      f.delete()
    }
    deleteRec(file)
    super.afterAll()
  }
}
