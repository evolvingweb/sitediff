build:
	docker build -t dergachev/sitediff .

# runs the last SUCCESSFUL image
run:
	docker run -i -t -p 4567:4567 -p 9022:22 dergachev/sitediff

# kill all containers, remove all untagged images
destroy:
	docker ps -a -q | xargs docker rm
	docker images -a | grep "^<none>" | awk '{print $$3}' | xargs docker rmi

# SSH into latest created image
latest:
	docker run -t -i $$(docker images -q | head -n 1) /bin/bash

ssh:
	echo "Warning: ssh support not implemented in sitediff Dockerfile yet"
	ssh root@localhost -p 9022

go: build run

# otherwise make is fooled by build/ directory, says "build is up to date"
.PHONY: build
