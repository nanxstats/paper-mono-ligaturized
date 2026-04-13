SHELL := /bin/bash
.SHELLFLAGS := -eo pipefail -c

LIGATURIZER_DIR := Ligaturizer
DM_MONO_DIR := dm-mono
OUTPUT_DIR := fonts
LIG_OUTPUT_DIR := $(LIGATURIZER_DIR)/fonts/output
DM_TARGET_DIR := $(LIGATURIZER_DIR)/fonts/dm-mono

FINAL_FONTS := \
	$(OUTPUT_DIR)/LigaDMMono-Light.ttf \
	$(OUTPUT_DIR)/LigaDMMono-LightItalic.ttf \
	$(OUTPUT_DIR)/LigaDMMono-Regular.ttf \
	$(OUTPUT_DIR)/LigaDMMono-Italic.ttf \
	$(OUTPUT_DIR)/LigaDMMono-Medium.ttf \
	$(OUTPUT_DIR)/LigaDMMono-MediumItalic.ttf

.DEFAULT_GOAL := all

.PHONY: all deps cleanup clean

all: cleanup

deps:
	@if ! command -v fontforge >/dev/null 2>&1; then \
		if ! command -v brew >/dev/null 2>&1; then \
			echo "Homebrew is required to install fontforge; please install Homebrew first." >&2; \
			exit 1; \
		fi; \
		brew install fontforge; \
	fi

cleanup: $(FINAL_FONTS)
	rm -rf $(LIGATURIZER_DIR) $(DM_MONO_DIR)

$(OUTPUT_DIR):
	mkdir -p $@

$(LIGATURIZER_DIR)/.git:
	git clone https://github.com/ToxicFrog/Ligaturizer.git $(LIGATURIZER_DIR)

$(LIGATURIZER_DIR)/fonts/fira/.git: $(LIGATURIZER_DIR)/.git
	git -C $(LIGATURIZER_DIR) submodule update --init --depth 1 fonts/fira

$(DM_MONO_DIR)/.git:
	git clone https://github.com/googlefonts/dm-mono.git --depth 1 $(DM_MONO_DIR)

$(DM_TARGET_DIR)/.prepared: $(DM_MONO_DIR)/.git $(LIGATURIZER_DIR)/.git
	rm -rf $(DM_TARGET_DIR)
	mkdir -p $(LIGATURIZER_DIR)/fonts
	mv $(DM_MONO_DIR)/exports $(DM_TARGET_DIR)
	touch $@

$(LIGATURIZER_DIR)/.patched: Makefile $(LIGATURIZER_DIR)/.git $(LIGATURIZER_DIR)/build.py $(LIGATURIZER_DIR)/ligatures.py
	@tmp=$$(mktemp) && \
	awk 'BEGIN { in_prefixed=0; in_renamed=0 } \
	/^prefixed_fonts[[:space:]]*=/ { \
		print "prefixed_fonts = ["; \
		print "    \"fonts/dm-mono/DMMono-Regular.ttf\","; \
		print "    \"fonts/dm-mono/DMMono-Italic.ttf\""; \
		print "]"; \
		in_prefixed=1; next; \
	} \
	in_prefixed { \
		if ($$0 ~ /^[[:space:]]*\]/) { in_prefixed=0 } \
		next; \
	} \
	/^renamed_fonts[[:space:]]*=/ { \
		print "renamed_fonts = {"; \
		print "    \"fonts/dm-mono/DMMono-Light.ttf\": \"Liga DM Mono\","; \
		print "    \"fonts/dm-mono/DMMono-LightItalic.ttf\": \"Liga DM Mono\","; \
		print "    \"fonts/dm-mono/DMMono-Medium.ttf\": \"Liga DM Mono\","; \
		print "    \"fonts/dm-mono/DMMono-MediumItalic.ttf\": \"Liga DM Mono\""; \
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
	@touch $@

$(LIGATURIZER_DIR)/.built: deps $(LIGATURIZER_DIR)/.patched $(DM_TARGET_DIR)/.prepared $(LIGATURIZER_DIR)/fonts/fira/.git
	$(MAKE) -C $(LIGATURIZER_DIR)
	touch $@

$(LIG_OUTPUT_DIR)/%.ttf: | $(LIGATURIZER_DIR)/.built
	@test -f $@

$(OUTPUT_DIR)/%.ttf: $(LIG_OUTPUT_DIR)/%.ttf | $(OUTPUT_DIR)
	cp $< $@

clean:
	rm -rf $(LIGATURIZER_DIR) $(DM_MONO_DIR) $(OUTPUT_DIR)
