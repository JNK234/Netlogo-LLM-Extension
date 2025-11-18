# Building the LLM Extension

## Prerequisites

- **Java 17** (required for building)
- **SBT 1.10.6+** (Scala Build Tool)

## Build Commands

### For Development (Fat JAR)

```bash
# Set Java 17
export JAVA_HOME=$(/usr/libexec/java_home -v 17)

# Build single JAR with all dependencies
sbt clean assembly
```

**Output:** `target/scala-3.7.0/llm.jar` (172MB)

### For Distribution (ZIP Package)

```bash
# Set Java 17
export JAVA_HOME=$(/usr/libexec/java_home -v 17)

# Build distribution package
sbt clean packageZip
```

**Output:** `llm-0.1.0.zip` (11MB)

## Build Outputs Explained

### Fat JAR (assembly)
- **Location**: `target/scala-3.7.0/llm.jar`
- **Size**: ~172MB
- **Type**: Single JAR with all dependencies bundled inside
- **Use**: Local development, simple installation
- **Install**: Copy one file to NetLogo extensions

### ZIP Package (packageZip)
- **Location**: `llm-0.1.0.zip` (project root)
- **Size**: ~11MB
- **Type**: Multiple JARs + documentation
- **Use**: Official releases, NetLogo Extension Library
- **Install**: Extract entire folder to NetLogo extensions

## Which Build Should I Use?

| Purpose | Command | Output |
|---------|---------|--------|
| **Testing locally** | `sbt assembly` | Fat JAR (172MB) |
| **Quick install** | `sbt assembly` | Fat JAR (172MB) |
| **Official release** | `sbt packageZip` | ZIP (11MB) |
| **Publish to library** | `sbt packageZip` | ZIP (11MB) |

## Common Issues

**Problem**: Build fails with SBT parser errors
**Solution**: Upgrade SBT to 1.10.6+ in `project/build.properties`:
```
sbt.version=1.10.6
```

**Problem**: Build fails with Java version errors
**Solution**: Make sure you're using Java 17:
```bash
java -version  # Should show 17.x.x
```

**Problem**: Old JAR still being used
**Solution**: Always use `clean` before building:
```bash
sbt clean assembly  # Not just 'assembly'
```
