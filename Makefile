SHELL := /bin/bash
.SHELLFLAGS := -eo pipefail -c

LIGATURIZER_DIR := Ligaturizer
PAPER_MONO_DIR := paper-mono
OUTPUT_DIR := fonts
LIG_OUTPUT_DIR := $(LIGATURIZER_DIR)/fonts/output
PAPER_TARGET_DIR := $(LIGATURIZER_DIR)/fonts/paper-mono

PAPER_MONO_WEIGHTS := \
	PaperMono-Thin \
	PaperMono-ExtraLight \
	PaperMono-Light \
	PaperMono-Regular \
	PaperMono-Medium \
	PaperMono-SemiBold \
	PaperMono-Bold \
	PaperMono-ExtraBold

SOURCE_FONTS := $(addprefix $(PAPER_MONO_DIR)/fonts/otf/,$(addsuffix .otf,$(PAPER_MONO_WEIGHTS)))
LIG_FONTS := $(addprefix $(LIG_OUTPUT_DIR)/Liga,$(addsuffix .otf,$(PAPER_MONO_WEIGHTS)))
FINAL_FONTS := $(addprefix $(OUTPUT_DIR)/Liga,$(addsuffix .otf,$(PAPER_MONO_WEIGHTS)))

.DEFAULT_GOAL := all
.SECONDARY: $(LIG_FONTS)

.PHONY: all build deps cleanup clean

all: build
	rm -rf $(LIGATURIZER_DIR) $(PAPER_MONO_DIR)

build: $(FINAL_FONTS)

deps:
	@if ! command -v fontforge >/dev/null 2>&1; then \
		if ! command -v brew >/dev/null 2>&1; then \
			echo "Homebrew is required to install fontforge; please install Homebrew first." >&2; \
			exit 1; \
		fi; \
		brew install fontforge; \
	fi

cleanup:
	rm -rf $(LIGATURIZER_DIR) $(PAPER_MONO_DIR)

$(OUTPUT_DIR):
	mkdir -p $@

$(LIGATURIZER_DIR)/.git:
	git clone https://github.com/ToxicFrog/Ligaturizer.git $(LIGATURIZER_DIR)

$(LIGATURIZER_DIR)/fonts/fira/.git: $(LIGATURIZER_DIR)/.git
	git -C $(LIGATURIZER_DIR) submodule update --init --depth 1 fonts/fira

$(PAPER_MONO_DIR)/.git:
	git clone --branch light-master --single-branch --depth 1 https://github.com/paper-design/paper-mono.git $(PAPER_MONO_DIR)

$(PAPER_MONO_DIR)/fonts/otf/%.otf: $(PAPER_MONO_DIR)/.git
	@test -f $@

$(PAPER_TARGET_DIR)/.prepared: $(SOURCE_FONTS) $(LIGATURIZER_DIR)/.git
	rm -rf $(PAPER_TARGET_DIR)
	mkdir -p $(PAPER_TARGET_DIR)
	cp $(SOURCE_FONTS) $(PAPER_TARGET_DIR)/
	@for font in $(PAPER_MONO_WEIGHTS); do \
		test -f "$(PAPER_TARGET_DIR)/$$font.otf"; \
	done
	touch $@

$(LIGATURIZER_DIR)/.patched: Makefile $(LIGATURIZER_DIR)/.git $(LIGATURIZER_DIR)/build.py $(LIGATURIZER_DIR)/ligatures.py
	@tmp=$$(mktemp) && \
	awk 'BEGIN { in_prefixed=0; in_renamed=0 } \
	/^prefixed_fonts[[:space:]]*=/ { \
		print "prefixed_fonts = ["; \
		print "]"; \
		in_prefixed=1; next; \
	} \
	in_prefixed { \
		if ($$0 ~ /^[[:space:]]*]/) { in_prefixed=0 } \
		next; \
	} \
	/^renamed_fonts[[:space:]]*=/ { \
		print "renamed_fonts = {"; \
		print "  '\''fonts/paper-mono/PaperMono-*.otf'\'': '\''Liga Paper Mono'\''"; \
		print "}"; \
		in_renamed=1; \
		if ($$0 ~ /}/) { in_renamed=0 } \
		next; \
	} \
	in_renamed { \
		if ($$0 ~ /^[[:space:]]*}/) { in_renamed=0 } \
		next; \
	} \
	{ print }' "$(LIGATURIZER_DIR)/build.py" > $$tmp && mv $$tmp "$(LIGATURIZER_DIR)/build.py"
	@tmp=$$(mktemp) && \
	awk 'BEGIN { \
		skip=0; \
		targets["    {   # &&"]=1;  \
		targets["    {   # ~@"]=1;  \
		targets["    {   # \\/"]=1; \
		targets["    {   # .?"]=1;  \
		targets["    {   # ?:"]=1;  \
		targets["    {   # ?="]=1;  \
		targets["    {   # ?."]=1;  \
		targets["    {   # ??"]=1;  \
		targets["    {   # ;;"]=1;  \
		targets["    {   # /\\"]=1; \
	} \
	targets[$$0] { skip=1; next } \
	skip && $$0 ~ /^[[:space:]]*},[[:space:]]*$$/ { skip=0; next } \
	skip { next } \
	{ print }' "$(LIGATURIZER_DIR)/ligatures.py" > $$tmp && mv $$tmp "$(LIGATURIZER_DIR)/ligatures.py"
	touch $@

$(LIGATURIZER_DIR)/.built: deps $(LIGATURIZER_DIR)/.patched $(PAPER_TARGET_DIR)/.prepared $(LIGATURIZER_DIR)/fonts/fira/.git
	$(MAKE) -C $(LIGATURIZER_DIR) without-characters
	touch $@

$(LIG_OUTPUT_DIR)/%.otf: | $(LIGATURIZER_DIR)/.built
	@test -f $@

$(OUTPUT_DIR)/%.otf: $(LIG_OUTPUT_DIR)/%.otf | $(OUTPUT_DIR)
	cp $< $@

clean:
	rm -rf $(LIGATURIZER_DIR) $(PAPER_MONO_DIR) $(OUTPUT_DIR)
