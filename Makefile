PROJECT_NAME := mkarchiso

DESTDIR :=
PREFIX := /usr
BINDIR := $(PREFIX)/bin
DATADIR := $(PREFIX)/share/$(PROJECT_NAME)

SCRIPTFILES = mkarchiso
LIBFILES    = library/*.sh
DATAFILES   = files/*
CONFIG      = config/*

.PHONY: install install-program install-config clean
all: $(SCRIPTFILES)

mkarchiso: mkiso.in
	sed -e 's@^libdir=.*@libdir=$(DATADIR)/library@' \
		-e 's@^config=.*@config=$(DATADIR)/config@' \
	    -e '/^mydir=.*library$$/d' \
		-e '/^mydir=.*config$$/d' \
	        mkiso.in \
	      > mkarchiso

install: install-program install-config

install-program:
	install -dm755                 "$(DESTDIR)$(BINDIR)"
	install -m755  mkarchiso       "$(DESTDIR)$(BINDIR)/mkarchiso"
	install -dm755                 "$(DESTDIR)$(DATADIR)"
	install -dm755                 "$(DESTDIR)$(DATADIR)/files"
	install -m644  $(DATAFILES)    "$(DESTDIR)$(DATADIR)/files/"
	install -dm755                 "$(DESTDIR)$(DATADIR)/config"
	install -m655  $(CONFIG)       "$(DESTDIR)$(DATADIR)/config/"
	install -dm755                 "$(DESTDIR)$(DATADIR)/library"
	install -m644 $(LIBFILES)      "$(DESTDIR)$(DATADIR)/library/"

clean:
	rm $(SCRIPTFILES)
