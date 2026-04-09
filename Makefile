ARCHS = armv7 armv7s
TARGET = iphone:10.3:10.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = socket

socket_FILES = src/main.m \
               src/AppDelegate.m \
               src/ViewController.m \
               src/Settings.m \
               src/Credits.m \
               src/jailbreak.m \
               src/patches.m \
               src/patchfinder.c \
               src/util.c \
               src/mpo_execve.s \
               src/exploit/oob_entry.c \
               src/exploit/memory.c \
               src/exploit/util.c

socket_CFLAGS = -Wall -fno-modules -Wno-deprecated-declarations -Wno-tautological-bitwise-compare -Isrc -Isrc/exploit
socket_OBJCFLAGS = -fobjc-arc
socket_LDFLAGS = -lSystem
socket_FRAMEWORKS = UIKit Foundation CoreFoundation
socket_RESOURCE_DIRS = Resources
socket_INSTALL_PATH = /Applications

include $(THEOS_MAKE_PATH)/application.mk

APP_DIR = $(THEOS_STAGING_DIR)/Applications/socket.app

after-stage::
	@# Strip the binary
	$(ECHO_NOTHING)$(TARGET_STRIP) $(APP_DIR)/socket$(ECHO_END)
	@# Compile storyboards if ibtool is available (macOS only)
	@if command -v ibtool >/dev/null 2>&1; then \
		for sb in $(APP_DIR)/Base.lproj/*.storyboard; do \
			[ -f "$$sb" ] || continue; \
			echo "Compiling $$(basename $$sb)..."; \
			ibtool --compile "$${sb}c" "$$sb" --minimum-deployment-target 10.0 && rm "$$sb"; \
		done; \
	fi
	@# Compile asset catalog if actool is available (macOS only)
	@if command -v actool >/dev/null 2>&1 && [ -d "$(APP_DIR)/Assets.xcassets" ]; then \
		echo "Compiling Assets.xcassets..."; \
		actool --compile $(APP_DIR) \
			--platform iphoneos \
			--minimum-deployment-target 10.0 \
			--app-icon AppIcon \
			--output-partial-info-plist $(APP_DIR)/partial.plist \
			$(APP_DIR)/Assets.xcassets && \
		/usr/libexec/PlistBuddy -c "Merge $(APP_DIR)/partial.plist" $(APP_DIR)/Info.plist && \
		rm -f $(APP_DIR)/partial.plist && \
		rm -rf $(APP_DIR)/Assets.xcassets; \
	fi
