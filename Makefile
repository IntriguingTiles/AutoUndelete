TARGET := iphone:clang:latest:7.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AutoUndelete

AutoUndelete_FILES = $(wildcard tweak/*.x tweak/*.xm tweak/*.m tweak/snudown/*.c tweak/snudown/html/*.c tweak/snudown/src/*.c)
AutoUndelete_CFLAGS = -fobjc-arc -Itweak/snudown/src -Itweak/snudown/html

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += autoundeleteprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
