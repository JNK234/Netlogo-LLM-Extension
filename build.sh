#!/bin/bash
# Build script for LLM Extension
# Creates fat JAR and cleans up loose dependency JARs

set -e

# Set Java 17
export JAVA_HOME=$(/usr/libexec/java_home -v 17)

echo "Building LLM Extension..."
sbt clean assembly

# Clean up loose JARs created by NetLogo plugin
rm -f *.jar 2>/dev/null || true

# Update dist folder
mkdir -p dist/llm
cp target/scala-3.7.0/llm.jar dist/llm/

# Auto-install to NetLogo 7.0.3
NETLOGO_EXT="$HOME/Developer/CCL/NetLogo 7.0.3/extensions/llm"
if [ -d "$(dirname "$NETLOGO_EXT")" ]; then
  mkdir -p "$NETLOGO_EXT"
  cp target/scala-3.7.0/llm.jar "$NETLOGO_EXT/"
  echo "Installed to: $NETLOGO_EXT"
fi

echo ""
echo "Build complete!"
echo "Fat JAR: target/scala-3.7.0/llm.jar"
echo "Install folder: dist/llm/"
