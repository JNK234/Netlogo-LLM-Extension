# Building the LLM Extension

## Prerequisites

- **Java 17** (required for building only)
- **SBT** (Scala Build Tool)

## Build Steps

### 1. Set Java 17

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 17)
```

### 2. Build the Extension

```bash
sbt clean assembly
```

This creates `target/scala-3.7.0/llm.jar` (approximately 180MB fat JAR with all dependencies).

## That's It!

The JAR file is now ready to install. See `INSTALL.md` for installation instructions.

## Build Output

- **Location**: `target/scala-3.7.0/llm.jar`
- **Type**: Fat JAR (all dependencies bundled inside)
- **Size**: ~180MB

## Common Issues

**Problem**: Build fails with Java version errors
**Solution**: Make sure you're using Java 17:
```bash
java -version  # Should show 17.x.x
```

**Problem**: Old JAR still being used
**Solution**: Always run `sbt clean assembly` (not just `assembly`)
