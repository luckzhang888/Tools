CARGO ?= cargo
PREFIX ?= /usr/local
DESTDIR ?=
TARGET ?=
PKG_ARCH ?=

TARGET_ARG := $(if $(TARGET),--target $(TARGET),)
TARGET_DIR := target/$(if $(TARGET),$(TARGET)/)release
BIN := $(TARGET_DIR)/serial-relay

.PHONY: all build check test deb install uninstall clean

all: build

build:
	$(CARGO) build --release --locked $(TARGET_ARG)

check:
	$(CARGO) fmt -- --check
	$(CARGO) clippy --all-targets --locked -- -D warnings
	$(CARGO) test --locked

test:
	$(CARGO) test --locked

deb:
	TARGET="$(TARGET)" PKG_ARCH="$(PKG_ARCH)" ./build-deb.sh deb

install: build
	install -D -m 0755 "$(BIN)" "$(DESTDIR)$(PREFIX)/bin/serial-relay"

uninstall:
	rm -f "$(DESTDIR)$(PREFIX)/bin/serial-relay"

clean:
	$(CARGO) clean
	rm -rf dist
