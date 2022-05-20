TARGET := iphone:clang:latest:7.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = AutoUndeletePrefs

AutoUndeletePrefs_FILES = AUDRootListController.m
AutoUndeletePrefs_FRAMEWORKS = UIKit
AutoUndeletePrefs_PRIVATE_FRAMEWORKS = Preferences
AutoUndeletePrefs_INSTALL_PATH = /Library/PreferenceBundles
AutoUndeletePrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
