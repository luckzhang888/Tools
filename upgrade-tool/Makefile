.PHONY: build-armv7 check deploy test-device

build-armv7:
	./scripts/build-armv7.sh

check:
	bash -n scripts/build-armv7.sh
	bash -n scripts/deploy.sh
	bash -n scripts/test-device.sh
	test -s cmake/toolchain-armv7.cmake
	test -s Dockerfile.armv7

deploy:
	./scripts/deploy.sh

test-device:
	./scripts/test-device.sh
