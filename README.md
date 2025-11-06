# Scala Hello World with Log4j

A simple Scala project demonstrating log4j integration for logging output.

## Project Structure

```
.
├── build.sbt                          # SBT build configuration
├── src
│   └── main
│       ├── scala
│       │   └── com
│       │       └── example
│       │           └── HelloWorld.scala   # Main application
│       └── resources
│           └── log4j2.properties          # Log4j configuration
└── README.md
```

## Requirements

- Java 8 or higher
- Scala 2.13.12
- SBT (Scala Build Tool)

## Running the Application

### Option 1: Run with SBT
```bash
sbt run
```

### Option 2: Build and Run JAR
Build the fat JAR (includes all dependencies):
```bash
sbt assembly
```

Run the JAR:
```bash
java -jar target/scala-2.13/scala-hello-world.jar
```

The JAR file will be created at `target/scala-2.13/scala-hello-world.jar` (approximately 7.8MB)

## Log4j Configuration

The log4j configuration is in `src/main/resources/log4j2.properties`. The current configuration:

- **Log Level**: INFO
- **Pattern**: Timestamp, log level, class name, line number, and message
- **Appender**: Console output

You can modify the log level by changing the `rootLogger.level` property:
- `debug` - Show all messages including debug
- `info` - Show info, warn, and error messages
- `warn` - Show only warnings and errors
- `error` - Show only errors

## Dependencies

- Apache Log4j 2.20.0 (API, Core, and SLF4J implementation)

