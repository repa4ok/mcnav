.PHONY: build app install clean

APP_NAME = MCNav
BUILD_DIR = .build/release
APP_DIR = $(APP_NAME).app

build:
	swift build -c release

app: build
	rm -rf $(APP_DIR)
	mkdir -p $(APP_DIR)/Contents/MacOS $(APP_DIR)/Contents/Resources
	cp $(BUILD_DIR)/MCNav $(APP_DIR)/Contents/MacOS/
	cp Info.plist $(APP_DIR)/Contents/
	cp AppIcon.icns $(APP_DIR)/Contents/Resources/

install: app
	rm -rf /Applications/$(APP_DIR)
	cp -r $(APP_DIR) /Applications/

clean:
	rm -rf .build $(APP_DIR)
