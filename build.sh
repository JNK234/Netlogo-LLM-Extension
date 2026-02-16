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

echo ""
echo "Build complete!"
echo "Fat JAR: target/scala-3.7.0/llm.jar"
echo "Install folder: dist/llm/"
echo ""
echo "To install:"
echo "  cp -r dist/llm \"/Applications/NetLogo 7.0.0/extensions/\""
