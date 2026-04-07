APP      = SlapClaude
BUNDLE   = $(APP).app
BIN      = .build/release/$(APP)
INSTALL  = /Applications/$(BUNDLE)

.PHONY: all build bundle install uninstall clean

all: bundle

build:
	swift build -c release

bundle: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(BIN) $(BUNDLE)/Contents/MacOS/$(APP)
	cp Info.plist $(BUNDLE)/Contents/Info.plist
	codesign --force --options runtime --entitlements entitlements.plist --sign - $(BUNDLE)
	tccutil reset Accessibility com.slapclaude.app 2>/dev/null || true
	@echo "Built $(BUNDLE) — re-grant Accessibility if prompted"

install: bundle
	rm -rf "$(INSTALL)"
	cp -r $(BUNDLE) "$(INSTALL)"
	@echo "Installed to $(INSTALL)"

uninstall:
	rm -rf "$(INSTALL)"

clean:
	swift package clean
	rm -rf $(BUNDLE)
