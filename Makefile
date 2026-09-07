.PHONY: build base desktop-x11 ubuntu workstation

build: base desktop-x11 ubuntu workstation

base:
	$(MAKE) -C images/base build

desktop-x11: base
	$(MAKE) -C images/desktop-x11 build

ubuntu:
	$(MAKE) -C images/ubuntu build

workstation: base
	$(MAKE) -C images/workstation build
