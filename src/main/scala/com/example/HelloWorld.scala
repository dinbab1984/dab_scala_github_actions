package com.example

import org.apache.logging.log4j.LogManager

object HelloWorld {
  private val logger = LogManager.getLogger(getClass)

  def main(args: Array[String]): Unit = {
    logger.info("Hello, World!")
    logger.debug("This is a debug message")
    logger.warn("This is a warning message")
    logger.error("This is an error message")
    
    logger.info("Scala log4j integration is working successfully!")
  }
}



