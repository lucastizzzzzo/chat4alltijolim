#!/bin/bash
# ============================================================================
# Chat4All - Build Script
# ============================================================================
# Purpose: Build all Maven modules before Docker Compose
# Usage: ./build.sh
# ============================================================================

set -e  # Exit on error

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🔨 Chat4All - Building all modules"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if Maven is installed
if ! command -v mvn &> /dev/null; then
    echo "❌ Maven not found. Please install Maven 3.8+ first."
    echo ""
    echo "Install on Ubuntu/Debian:"
    echo "  sudo apt install maven"
    echo ""
    echo "Install on macOS:"
    echo "  brew install maven"
    exit 1
fi

MAVEN_VERSION=$(mvn -version | head -n 1 | awk '{print $3}')
echo "✓ Maven found: $MAVEN_VERSION"
echo ""

# Build all modules
echo "📦 Building all modules with Maven..."
echo ""

mvn clean package -DskipTests

if [ $? -eq 0 ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✅ Build successful!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "JARs created:"
    echo "  • api-service/target/api-service-1.0.0-SNAPSHOT.jar"
    echo "  • router-worker/target/router-worker-1.0.0-SNAPSHOT.jar"
    echo "  • connector-whatsapp/target/connector-whatsapp-1.0.0-SNAPSHOT.jar"
    echo "  • connector-instagram/target/connector-instagram-1.0.0-SNAPSHOT.jar"
    echo ""
    echo "Next steps:"
    echo "  docker-compose up -d"
    echo ""
else
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ❌ Build failed!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Common issues:"
    echo "  • Java 17 not installed: sudo apt install openjdk-17-jdk"
    echo "  • Maven version < 3.8: Update Maven"
    echo "  • Network issues: Check internet connection"
    exit 1
fi
