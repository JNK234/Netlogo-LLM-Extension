// (C) Uri Wilensky. https://github.com/NetLogo/LLM-Extension

package org.nlogo.extensions.llm

import org.scalatest.BeforeAndAfterAll

import java.io.File
import org.nlogo.headless.TestLanguage

object Tests {
  val testFileNames = Seq("tests.txt")
  val testFiles     = testFileNames.map( (f) => (new File(f)).getCanonicalFile )
}

class Tests extends TestLanguage(Tests.testFiles) with BeforeAndAfterAll {
  System.setProperty("org.nlogo.preferHeadless", "true")

  override def afterAll(): Unit = {
    val file = new File("tmp/llm")
    def deleteRec(f: File): Unit = {
      if (f.isDirectory) {
        f.listFiles().foreach(deleteRec)
      }
      f.delete()
    }
    deleteRec(file)
  }
}
