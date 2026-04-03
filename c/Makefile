CC = gcc
CFLAGS = -shared -fPIC
LDFLAGS = -ldl
OUT_DIR = lib
SOURCE = src/flock_shim.c

TARGET_64 = $(OUT_DIR)/64/flock_shim.so
TARGET_32 = $(OUT_DIR)/32/flock_shim.so

.PHONY: all clean check-multilib

all: $(OUT_DIR) $(TARGET_64) $(TARGET_32)

$(OUT_DIR):
	mkdir -p $(OUT_DIR)/64 $(OUT_DIR)/32

# 64-bit version
$(TARGET_64): $(SOURCE)
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

# 32-bit version (Requires gcc-multilib, libc6-dev-i386)
$(TARGET_32): $(SOURCE)
	@echo "Checking for 32-bit build support..."
	$(CC) -m32 $(CFLAGS) -o $@ $< $(LDFLAGS) || (echo "32-bit compilation failed (is gcc-multilib installed?)" && exit 0)

clean:
	rm -rf $(OUT_DIR)
	@echo "Cleaned [$(OUT_DIR)]"
