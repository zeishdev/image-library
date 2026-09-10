IMAGE = ghcr.io/zeishdev/base
TAG   = latest
DIR   = $(shell pwd)

.PHONY: build run push

build:
	docker build -t $(IMAGE):$(TAG) $(DIR)

run:
	docker run --rm -it $(IMAGE):$(TAG) /bin/bash

push:
	docker push $(IMAGE):$(TAG)
