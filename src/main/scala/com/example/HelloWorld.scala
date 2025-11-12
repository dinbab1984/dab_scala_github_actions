package com.example

import org.apache.logging.log4j.core.LoggerContext
import org.apache.logging.log4j.core.config.builder.api.ConfigurationBuilderFactory
import org.apache.logging.log4j.{Level, LogManager}

object HelloWorld {
  private lazy val logger = LogManager.getLogger(getClass)

  private def configureConsoleLogging(level: Level = Level.DEBUG): Unit = {
    val builder = ConfigurationBuilderFactory.newConfigurationBuilder()
    builder.setStatusLevel(Level.ERROR)
    builder.setConfigurationName("ProgrammaticConsoleConfig")

    val layout = builder
      .newLayout("PatternLayout")
      .addAttribute("pattern", "%d{yyyy-MM-dd HH:mm:ss.SSS} [%t] %-5level %logger{36} - %msg%n")

    val consoleAppender = builder
      .newAppender("Console", "CONSOLE")
      .add(layout)

    builder.add(consoleAppender)
    builder.add(builder.newRootLogger(level).add(builder.newAppenderRef("Console")))

    val ctx = LoggerContext.getContext(false)
    val config = builder.build()
    ctx.stop()
    ctx.start(config)
  }

  def main(args: Array[String]): Unit = {
    configureConsoleLogging()
    logger.info("Hello, World!")
    logger.debug("This is a debug message")
    logger.warn("This is a warning message")
    logger.error("This is an error message")
    
    logger.info("Scala log4j integration is working successfully!")
  }
}



