# Run from ios/. See CLAUDE.md for when to use each target.
SIM_IPHONE ?= iPhone 17
SIM_WATCH ?= Apple Watch Series 11 (46mm)
XCODEBUILD = xcodebuild -project KeepThePace.xcodeproj -derivedDataPath build CODE_SIGNING_ALLOWED=NO -quiet

.PHONY: generate test golden build-ios build-watch test-app test-ui

generate:
	xcodegen generate

test:
	cd PaceKit && swift test

# Writes to a temp file first so a failed run can't truncate the committed fixture.
golden:
	mkdir -p build
	cd .. && node --experimental-strip-types --no-warnings ios/PaceKit/Scripts/make-golden.mjs > ios/build/golden.json.tmp
	mv build/golden.json.tmp PaceKit/Tests/PaceKitTests/Fixtures/golden.json

build-ios: generate
	$(XCODEBUILD) -scheme KeepThePace -destination 'platform=iOS Simulator,name=$(SIM_IPHONE)' build

build-watch: generate
	$(XCODEBUILD) -scheme KeepThePaceWatch -destination 'platform=watchOS Simulator,name=$(SIM_WATCH)' build

# The app's unit tests (WalkSession with fake GPS, routing, Live Activity and haptics) on the
# iPhone simulator. Not -quiet, so the per-test results and "** TEST SUCCEEDED **" are printed.
test-app: generate
	xcodebuild -project KeepThePace.xcodeproj -derivedDataPath build CODE_SIGNING_ALLOWED=NO -scheme KeepThePace -destination 'platform=iOS Simulator,name=$(SIM_IPHONE)' -only-testing:KeepThePaceTests test

# The demo-walk UI test on the iPhone simulator. Takes about 3 minutes. Not -quiet, so the
# per-test results and "** TEST SUCCEEDED **" are printed.
test-ui: generate
	xcodebuild -project KeepThePace.xcodeproj -derivedDataPath build CODE_SIGNING_ALLOWED=NO -scheme KeepThePace -destination 'platform=iOS Simulator,name=$(SIM_IPHONE)' -only-testing:KeepThePaceUITests test
