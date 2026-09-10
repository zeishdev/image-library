IMAGE = ghcr.io/zeishdev/desktop-x11
TAG   = latest
DIR   = $(shell pwd)

.PHONY: build run push

build:
	docker build -t $(IMAGE):$(TAG) $(DIR)

run:
	docker run --rm -p 6080:6080 \
		--shm-size=256m \
		$(IMAGE):$(TAG)

push:
	docker push $(IMAGE):$(TAG)
