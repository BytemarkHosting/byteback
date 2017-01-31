
all: docs

man/%.man: ./man/%.txt
	[ -d man ] || mkdir man
	txt2man -s 1 -t $(basename $(notdir $<)) $< | sed -e 's/\\\\fB/\\fB/' > $@

docs: man/byteback-prune.man man/byteback-restore.man man/byteback-backup.man

# To be written
# man/byteback-snapshot.man man/byteback-setup-client.man man/byteback-setup-client-receive.man man/byteback-receive.man

test:
	ruby test/ts_byteback.rb

clean:
	$(RM)  man/*.man

.PHONY: clean docs all test

