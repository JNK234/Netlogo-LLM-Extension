import sbt.nio.file.FileTreeView

enablePlugins(org.nlogo.build.NetLogoExtension)

name := "LLM-Extension"
version := "0.1.0"
isSnapshot := true

netLogoExtName      := "llm"
netLogoClassManager := "org.nlogo.extensions.llm.LLMExtension"
netLogoVersion      := "7.0.0-2486d1e"
netLogoShortDescription := "Multi-provider LLM extension for NetLogo agents"
netLogoLongDescription := "A NetLogo extension that provides unified interface for multiple LLM providers including OpenAI, Anthropic, Gemini, and Ollama"
netLogoHomepage := "https://github.com/JNK234/Netlogo-LLM-Extension"

// Package only essential files in the zip distribution
netLogoZipExtras := {
  val base = baseDirectory.value

  // Only include core documentation and config reference
  Seq(
    base / "NetLogo-LLM-Extension-Documentation.md",
    base / "demos" / "config-reference.txt"
  ).filter(_.exists())
}

scalaVersion          := "3.7.0"
Compile / scalaSource := baseDirectory.value / "src" / "main"
Test / scalaSource    := baseDirectory.value / "src" / "test"
scalacOptions        ++= Seq("-deprecation", "-unchecked", "-Xfatal-warnings", "-encoding", "us-ascii", "-release", "17")

libraryDependencies ++= Seq(
  "io.circe" %% "circe-yaml" % "0.15.0",
  "com.lihaoyi" %% "ujson" % "4.0.0"
)

ThisBuild / scalafixDependencies += "com.github.liancheng" %% "organize-imports" % "0.6.0"

// Assembly configuration for fat JAR with all dependencies
assembly / assemblyMergeStrategy := {
  case "module-info.class" => MergeStrategy.discard
  case x if x.endsWith("/module-info.class") => MergeStrategy.discard
  case PathList("META-INF", "versions", "9", "module-info.class") => MergeStrategy.discard
  case PathList("META-INF", xs @ _*) => MergeStrategy.discard
  case _ => MergeStrategy.first
}

// Include Scala library in the assembly
assembly / assemblyOption := (assembly / assemblyOption).value.withIncludeScala(true)

// Output JAR with extension name (llm.jar)
assembly / assemblyJarName := s"${netLogoExtName.value}.jar"
