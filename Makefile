###########################################################
#
# Work in progress.
#
############################################################
ifneq ($(MAKECMDGOALS),docker)
ifneq ($(MAKECMDGOALS),docker-debug)

ifndef ONL
$(error Please source the setup.env script at the root of the ONL tree)
endif

include $(ONL)/make/config.mk

# All available architectures.
ALL_ARCHES := amd64 powerpc armel arm64 armhf

# Build rule for each architecture.
define build_arch_template
$(1) :
	$(MAKE) -C builds/$(1)
endef
$(foreach a,$(ALL_ARCHES),$(eval $(call build_arch_template,$(a))))


# Available build architectures based on the current suite.
#
# jessie default trimmed to amd64 only - the powerpc loader-initrd target
# dies with "Package onl-platform-config-x86-64-stordis-bf2556x-1t-r0:
# powerpc does not exist" because PLATFORMS gets inherited from amd64
# (onlpm itself returns the right per-arch list when queried directly,
# but the powerpc loader Makefile ends up with x86-64 platforms anyway).
# armel hits the same. The amd64 installer was already in RELEASE/ by
# then, so the failure is purely cosmetic but trips up `make all` exit
# status. Restore with:
#   make BUILD_ARCHES_jessie="amd64 powerpc armel" all
# if cross-arch is actually needed.
BUILD_ARCHES_wheezy := amd64 powerpc
BUILD_ARCHES_jessie := amd64
BUILD_ARCHES_stretch := arm64 amd64 armel armhf

# Build available architectures by default.
.DEFAULT_GOAL := all
all: $(BUILD_ARCHES_$(ONL_DEBIAN_SUITE))


rebuild:
	$(ONLPM) --rebuild-pkg-cache


modclean:
	rm -rf $(ONL)/make/modules/modules.*

endif
endif

.PHONY: docker

ifndef VERSION
VERSION := 8
endif

docker_check:
	@which docker > /dev/null || (echo "*** Docker appears to be missing. Please install docker.io in order to build OpenNetworkLinux." && exit 1)

docker: docker_check
	@docker/tools/onlbuilder -$(VERSION) --isolate --hostname onlbuilder$(VERSION) --pull --autobuild --non-interactive

# create an interative docker shell, for debugging builds
docker-debug: docker_check
	@docker/tools/onlbuilder -$(VERSION) --isolate --hostname onlbuilder$(VERSION) --pull


versions:
	$(ONL)/tools/make-versions.py --import-file=$(ONL)/tools/onlvi --class-name=OnlVersionImplementation --output-dir $(ONL)/make/versions --force

relclean:
	@find $(ONL)/RELEASE -name "ONL-*" -delete
