import sbt.nio.file.FileTreeView

enablePlugins(org.nlogo.build.NetLogoExtension)

name := "LLM-Extension"
version := "0.1.0"
isSnapshot := true

netLogoExtName      := "llm"
netLogoClassManager := "org.nlogo.extensions.llm.LLMExtension"
netLogoVersion      := "6.3.0"
netLogoShortDescription := "Multi-provider LLM extension for NetLogo agents"
netLogoLongDescription := "A NetLogo extension that provides unified interface for multiple LLM providers including OpenAI, Anthropic, Gemini, and Ollama"
netLogoHomepage := "https://github.com/yourusername/NetLogoLLMExtension"
netLogoZipExtras := FileTreeView.default.list((baseDirectory.value / "demos").toGlob / "*.nlogo").map(_._1.toFile)

scalaVersion          := "2.12.17"
Compile / scalaSource := baseDirectory.value / "src" / "main"
Test / scalaSource    := baseDirectory.value / "src" / "test"
scalacOptions        ++= Seq("-deprecation", "-unchecked", "-Xfatal-warnings", "-encoding", "us-ascii", "-release", "11")

libraryDependencies ++= Seq(
  "com.lihaoyi" %% "upickle" % "3.1.0",
  "com.softwaremill.sttp.client3" %% "core" % "3.8.15"
)

ThisBuild / scalafixDependencies += "com.github.liancheng" %% "organize-imports" % "0.6.0"