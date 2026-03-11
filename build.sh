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

# Auto-install to NetLogo extensions directory
# Override with: NETLOGO_DIR=/path/to/NetLogo ./build.sh
if [ -n "$NETLOGO_DIR" ]; then
  NETLOGO_EXT="$NETLOGO_DIR/extensions/llm"
else
  # Search common locations
  for candidate in \
    "/Applications/NetLogo"*"/extensions" \
    "$HOME/Applications/NetLogo"*"/extensions" \
    "$HOME/Developer/CCL/NetLogo"*"/extensions"; do
    if [ -d "$candidate" ]; then
      NETLOGO_EXT="$candidate/llm"
      break
    fi
  done
fi

if [ -n "$NETLOGO_EXT" ]; then
  mkdir -p "$NETLOGO_EXT"
  cp target/scala-3.7.0/llm.jar "$NETLOGO_EXT/"
  echo "Installed to: $NETLOGO_EXT"
else
  echo "NetLogo not found. Copy target/scala-3.7.0/llm.jar to your NetLogo extensions/llm/ directory."
  echo "Or re-run with: NETLOGO_DIR=/path/to/NetLogo ./build.sh"
fi

echo ""
echo "Build complete!"
echo "Fat JAR: target/scala-3.7.0/llm.jar"
echo "Install folder: dist/llm/"
