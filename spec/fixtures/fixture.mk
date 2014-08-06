start_fixtures:
	docker build -t dergachev/sitediff-fixture $$(pwd)/spec/fixtures
	docker run 	--detach \
		--publish 8881:80 \
		--volume $$(pwd)/spec/fixtures/before:/var/show \
		--name fixture_before \
		--workdir /var/show \
		dergachev/sitediff-fixture python -m SimpleHTTPServer 80
	docker run  --detach \
		--publish 8882:80 \
		--volume $$(pwd)/spec/fixtures/after:/var/show \
		--name fixture_after \
		--workdir /var/show \
		dergachev/sitediff-fixture python -m SimpleHTTPServer 80

stop_fixtures:
	docker stop fixture_before fixture_after
	docker rm fixture_before fixture_after

sitediff_fixtures:
	make sitediff before=fixture_before after=fixture_after tests=spec/fixtures/config.yaml
