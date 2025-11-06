name := "scala-hello-world"

version := "0.1.0"

scalaVersion := "2.13.12"

// Enable scalafix
semanticdbEnabled := true
semanticdbVersion := scalafixSemanticdb.revision

// Scala compiler options for scalafix
scalacOptions ++= Seq(
  "-Wunused:imports",     // Warn about unused imports
  "-Wunused:patvars",     // Warn about unused pattern variables
  "-Wunused:privates",    // Warn about unused private definitions
  "-Wunused:locals",      // Warn about unused local definitions
  "-Wunused:explicits",   // Warn about unused explicit parameters
  "-Wunused:implicits",   // Warn about unused implicit parameters
  "-deprecation",         // Warn about deprecated features
  "-feature"              // Warn about features that should be imported explicitly
)

libraryDependencies ++= Seq(
  "org.apache.logging.log4j" % "log4j-api" % "2.20.0",
  "org.apache.logging.log4j" % "log4j-core" % "2.20.0",
  "org.apache.logging.log4j" % "log4j-slf4j-impl" % "2.20.0"
)

// Assembly configuration for fat JAR
assembly / assemblyJarName := "scala-hello-world.jar"
assembly / mainClass := Some("com.example.HelloWorld")

// Merge strategy for handling duplicate files
assembly / assemblyMergeStrategy := {
  case PathList("META-INF", xs @ _*) => xs match {
    case "MANIFEST.MF" :: Nil => MergeStrategy.discard
    case "services" :: _ => MergeStrategy.concat
    case _ => MergeStrategy.discard
  }
  case "reference.conf" => MergeStrategy.concat
  case "application.conf" => MergeStrategy.concat
  case x if x.endsWith(".properties") => MergeStrategy.first
  case x if x.endsWith(".class") => MergeStrategy.first
  case x if x.endsWith(".proto") => MergeStrategy.first
  case _ => MergeStrategy.first
}
