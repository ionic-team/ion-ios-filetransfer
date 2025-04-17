cd ..

rm -rf build

xcodebuild archive \
-scheme IONFileTrasnsferLib \
-configuration Release \
-destination 'generic/platform=iOS Simulator' \
-archivePath './scripts/build/IONFileTrasnsferLib.framework-iphonesimulator.xcarchive' \
SKIP_INSTALL=NO \
BUILD_LIBRARIES_FOR_DISTRIBUTION=YES


xcodebuild archive \
-scheme IONFileTrasnsferLib \
-configuration Release \
-destination 'generic/platform=iOS' \
-archivePath './scripts/build/IONFileTrasnsferLib.framework-iphoneos.xcarchive' \
SKIP_INSTALL=NO \
BUILD_LIBRARIES_FOR_DISTRIBUTION=YES


xcodebuild -create-xcframework \
-framework './scripts/build/IONFileTrasnsferLib.framework-iphonesimulator.xcarchive/Products/Library/Frameworks/IONFileTrasnsferLib.framework' \
-framework './scripts/build/IONFileTrasnsferLib.framework-iphoneos.xcarchive/Products/Library/Frameworks/IONFileTrasnsferLib.framework' \
-output './scripts/build/IONFileTrasnsferLib.xcframework'