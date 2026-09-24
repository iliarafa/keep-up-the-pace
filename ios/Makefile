# Run from ios/. See CLAUDE.md for when to use each target.
SIM_IPHONE ?= iPhone 17
SIM_WATCH ?= Apple Watch Series 11 (46mm)
XCODEBUILD = xcodebuild -project KeepThePace.xcodeproj -derivedDataPath build CODE_SIGNING_ALLOWED=NO -quiet

.PHONY: generate test golden build-ios build-watch test-app test-ui sim-start sim-walk

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

# Simulated GPS for the booted iPhone simulator. `make sim-start` puts it near Grand Central, about
# 500 m from Bryant Park. Start a walk to Bryant Park in the app, then `make sim-walk` walks there at
# SIM_SPEED m/s. Try SIM_SPEED=0.6 to fall behind and SIM_SPEED=3 to get ahead.
SIM_FROM ?= 40.7527,-73.9772
SIM_TO ?= 40.75377,-73.98358
SIM_SPEED ?= 1.4

sim-start:
	xcrun simctl location booted set $(SIM_FROM)

sim-walk:
	xcrun simctl location booted start --speed=$(SIM_SPEED) $(SIM_FROM) $(SIM_TO)
