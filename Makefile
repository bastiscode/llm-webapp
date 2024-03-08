.PHONY: build_web
build_web:
	docker run -v ${PWD}:/build --workdir /build cirrusci/flutter:stable flutter build web --release

.PHONY: build_docker
build_docker:
	docker build -t $(IMAGE) .
