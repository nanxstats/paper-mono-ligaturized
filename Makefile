SHELL := /bin/bash

# Paper Mono v1.000. Ligaturizer pins its own fonts/fira submodule.
PAPER_MONO_REV := e6eaeceaef02e77e3db997711e07a16378de2bd7
LIGATURIZER_REV := c4065187a544a8fab40826fc91db1c6180a2d342
FONTTOOLS_VERSION := 4.68.0
BUILD_DIR := .build
PAPER_MONO_DIR := $(BUILD_DIR)/$(PAPER_MONO_REV)/paper-mono
LIGATURIZER_DIR := $(BUILD_DIR)/$(LIGATURIZER_REV)/Ligaturizer
FONTTOOLS_DIR := $(BUILD_DIR)/fonttools-$(FONTTOOLS_VERSION)
OUTPUT_DIR := fonts

WEIGHTS := Thin ExtraLight Light Regular Medium SemiBold Bold ExtraBold
SOURCE_FONTS := $(addprefix $(PAPER_MONO_DIR)/fonts/otf/PaperMono-,$(addsuffix .otf,$(WEIGHTS)))
FINAL_FONTS := $(addprefix $(OUTPUT_DIR)/LigaPaperMono-,$(addsuffix .otf,$(WEIGHTS)))
BUILD_DEPS := scripts/build_font.py Makefile $(LIGATURIZER_DIR)/.ready $(FONTTOOLS_DIR)/.ready

.PHONY: all build deps cleanup clean

all: build
	$(MAKE) cleanup

build: $(FINAL_FONTS)

deps:
	@command -v fontforge >/dev/null || brew install fontforge
	@command -v hb-shape >/dev/null || brew install harfbuzz

define checkout
	mkdir -p $(@D)
	git -C $(@D) init -q
	git -C $(@D) fetch -q --depth 1 https://github.com/$(1).git $(2)
	git -C $(@D) checkout -q --detach $(2)
endef

$(PAPER_MONO_DIR)/.ready:
	$(call checkout,paper-design/paper-mono,$(PAPER_MONO_REV))
	touch $@

$(LIGATURIZER_DIR)/.ready:
	$(call checkout,ToxicFrog/Ligaturizer,$(LIGATURIZER_REV))
	git -C $(@D) submodule update --init --depth 1 fonts/fira
	touch $@

$(FONTTOOLS_DIR)/.ready:
	python3 -m pip install --disable-pip-version-check --no-deps --only-binary=:all: --platform any \
		--target $(@D) fonttools==$(FONTTOOLS_VERSION)
	touch $@

$(SOURCE_FONTS): | $(PAPER_MONO_DIR)/.ready
	@test -f $@

$(OUTPUT_DIR):
	mkdir -p $@

$(FINAL_FONTS): $(OUTPUT_DIR)/LigaPaperMono-%.otf: $(PAPER_MONO_DIR)/fonts/otf/PaperMono-%.otf $(BUILD_DEPS) | deps $(OUTPUT_DIR)
	@set -o pipefail; \
		PYTHONPATH="$(abspath $(LIGATURIZER_DIR)):$(abspath $(FONTTOOLS_DIR))" \
		SOURCE_DATE_EPOCH=$$(git -C $(PAPER_MONO_DIR) show -s --format=%ct HEAD) \
		fontforge -skippyplug -lang=py -script scripts/build_font.py $< $@ 2>&1 \
		| sed '/^This contextual rule applies no lookups\.$$/d'

cleanup:
	rm -rf $(BUILD_DIR)

clean: cleanup
	rm -f $(FINAL_FONTS)
