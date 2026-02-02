#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/common.sh"

PROJECT_NAME="${1:-}"
LICENSE_FILE="${2:-}"
BUILD_DIR="./build"

if [ -z "$PROJECT_NAME" ] || [ -z "$LICENSE_FILE" ]; then
	log_error "Usage: build_framework.sh <project_name> <license_file>"
	exit 1
fi

trap 'log_error "Build failed."' ERR

# Validate prerequisites
check_command "xcodebuild"
check_file "${PROJECT_NAME}.xcodeproj/project.pbxproj"
check_file "$LICENSE_FILE"

# Check for optional dependencies
if ! check_command "xcbeautify"; then
    log_warning "xcbeautify not found, output will not be formatted"
    XCBEAUTIFY_CMD="cat"
else
    XCBEAUTIFY_CMD="xcbeautify"
fi

log_info "🛠️ Building XCFramework for ${PROJECT_NAME}..."

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

xcodebuild archive \
	-scheme "$PROJECT_NAME" \
	-configuration Release \
	-destination 'generic/platform=iOS Simulator' \
	-archivePath "$BUILD_DIR/${PROJECT_NAME}.framework-iphonesimulator.xcarchive" \
	SKIP_INSTALL=NO \
	BUILD_LIBRARIES_FOR_DISTRIBUTION=YES | ${XCBEAUTIFY_CMD}

xcodebuild archive \
	-scheme "$PROJECT_NAME" \
	-configuration Release \
	-destination 'generic/platform=iOS' \
	-archivePath "$BUILD_DIR/${PROJECT_NAME}.framework-iphoneos.xcarchive" \
	SKIP_INSTALL=NO \
	BUILD_LIBRARIES_FOR_DISTRIBUTION=YES | ${XCBEAUTIFY_CMD}

XCFRAMEWORK_PATH="$BUILD_DIR/${PROJECT_NAME}.xcframework"

xcodebuild -create-xcframework \
	-framework "$BUILD_DIR/${PROJECT_NAME}.framework-iphonesimulator.xcarchive/Products/Library/Frameworks/${PROJECT_NAME}.framework" \
	-debug-symbols "$BUILD_DIR/${PROJECT_NAME}.framework-iphonesimulator.xcarchive/dSYMs/${PROJECT_NAME}.framework.dSYM" \
	-framework "$BUILD_DIR/${PROJECT_NAME}.framework-iphoneos.xcarchive/Products/Library/Frameworks/${PROJECT_NAME}.framework" \
	-debug-symbols "$BUILD_DIR/${PROJECT_NAME}.framework-iphoneos.xcarchive/dSYMs/${PROJECT_NAME}.framework.dSYM" \
	-output "$XCFRAMEWORK_PATH"

# Validate XCFramework was created successfully
if [ ! -d "$XCFRAMEWORK_PATH" ]; then
	log_error "XCFramework creation failed"
	exit 1
fi

# Create distribution zip
LICENSE_BASENAME="$(basename "$LICENSE_FILE")"
cp "$LICENSE_FILE" "$BUILD_DIR"
cd "$BUILD_DIR"
zip -r "${PROJECT_NAME}.zip" "${PROJECT_NAME}.xcframework" "$LICENSE_BASENAME"
mv "${PROJECT_NAME}.zip" ..

log_success "XCFramework built: ${PROJECT_NAME}.zip"
