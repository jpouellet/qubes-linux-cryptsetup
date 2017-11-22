# Makefile for fetching and verifying things hosted on kernel.org
#
# Makes two cryptographic verifications:
# 1. Trust-on-first-use pinned SHA512 of .tar.xz (hashes in tofu/*)
# 2. GPG sigature from software author of .tar (keys in keys/<author>/*)
#
# If the outer trust-on-first-use check fails, we don't expose xz or gpg
# attack surfaces to untrusted input. The 2nd gpg check is always made
# to verify the software's provenance (because the first fetch when
# the initial SHA512 was measured could have been man-in-the-middled).
#
# To use, set KORG_TARS to URLs of desired .tar files in Makefile.vars
# Direct .tar downloads don't actually exist, hence the .tar.xz dance.
#
# For background information and discussion of rationale, see:
#  - https://groups.google.com/d/topic/qubes-devel/cChKvqCXQ58/discussion

.DEFAULT_GOAL = get-sources
.SECONDEXPANSION:

.PHONY: get-sources verify-sources clean clean-sources

SHELL := bash

include Makefile.vars

UNTRUSTED_SUFF := .UNTRUSTED

FETCH_CMD := wget --no-use-server-timestamps -q -O

ALL_URLS := $(addsuffix .xz,$(KORG_TARS)) $(addsuffix .sign,$(KORG_TARS))
ALL_FILES := $(notdir $(KORG_TARS) $(ALL_URLS))

%.sign:
	$(FETCH_CMD) $@ $(filter %.sign,$(ALL_URLS))

keys/%.gpg: $$(sort $$(wildcard keys/$$*/*.asc))
	cat $^ | gpg --dearmor >$@

%: tofu/%.sha512
	$(FETCH_CMD) $@$(UNTRUSTED_SUFF) $(filter %/$*,$(ALL_URLS))
	sha512sum --status -c <(printf "$$(cat $<)  -\n") <$@$(UNTRUSTED_SUFF) || \
		{ echo "Wrong SHA512 checksum on $@$(UNTRUSTED_SUFF)!"; exit 1; }
	mv $@$(UNTRUSTED_SUFF) $@

%: %.xz %.sign keys/$$(firstword $$(subst -, ,$$*)).gpg
	xzcat <$< >$@$(UNTRUSTED_SUFF)
	gpgv --keyring $(word 3,$^) $(word 2,$^) $@$(UNTRUSTED_SUFF) 2>/dev/null || \
		{ echo "Wrong signature on $@$(UNTRUSTED_SUFF)!"; exit 1; }
	mv $@$(UNTRUSTED_SUFF) $@

get-sources: $(ALL_FILES)

verify-sources:

clean:

clean-sources:
	rm -rf $(ALL_FILES)
