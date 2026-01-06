# Makefile

MODULE_big = art
EXTENSION = art
DATA = art.control $(wildcard art--*.sql)
PGFILEDESC = "art index"

OBJS = art.o \
	   art_cost.o \
	   art_insert.o \
	   art_pageops.o \
	   art_scan.o \
	   art_utils.o \
	   art_vacuum.o \
	   art_validate.o

ifdef PG_CONFIG_PATH
PG_CONFIG= $(PG_CONFIG_PATH)
else
PG_CONFIG = pg_config
endif

PGXS := $(shell $(PG_CONFIG) --pgxs)
# Check if we are on macOS and if we can find the SDK path
ifeq ($(shell uname), Darwin)
    SDK_PATH := $(shell xcrun --show-sdk-path 2>/dev/null)
    ifneq ($(SDK_PATH),)
        PG_CPPFLAGS += -isysroot $(SDK_PATH)
    endif
endif

include $(PGXS)

REGRESS =
