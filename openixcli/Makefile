.PHONY: build-armv7 check deploy test-device

build-armv7:
	./scripts/build-armv7.sh

check:
	bash -n scripts/build-armv7.sh
	bash -n scripts/deploy.sh
	bash -n scripts/test-device.sh
	test -s Cargo.lock
	test -s Dockerfile.armv7
	test -s patches/0001-reject-storage-type-mismatch.patch

deploy:
	./scripts/deploy.sh

test-device:
	./scripts/test-device.sh
