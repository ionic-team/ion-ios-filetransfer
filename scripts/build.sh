cd ..

rm -rf build

xcodebuild archive \
-scheme IONFileTransferLib \
-configuration Release \
-destination 'generic/platform=iOS Simulator' \
-archivePath './scripts/build/IONFileTransferLib.framework-iphonesimulator.xcarchive' \
SKIP_INSTALL=NO \
BUILD_LIBRARIES_FOR_DISTRIBUTION=YES


xcodebuild archive \
-scheme IONFileTransferLib \
-configuration Release \
-destination 'generic/platform=iOS' \
-archivePath './scripts/build/IONFileTransferLib.framework-iphoneos.xcarchive' \
SKIP_INSTALL=NO \
BUILD_LIBRARIES_FOR_DISTRIBUTION=YES


xcodebuild -create-xcframework \
-framework './scripts/build/IONFileTransferLib.framework-iphonesimulator.xcarchive/Products/Library/Frameworks/IONFileTransferLib.framework' \
-framework './scripts/build/IONFileTransferLib.framework-iphoneos.xcarchive/Products/Library/Frameworks/IONFileTransferLib.framework' \
-output './scripts/build/IONFileTransferLib.xcframework'
