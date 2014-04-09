build_sitediff:
	docker build -t dergachev/sitediff .

include spec/fixtures/fixture.mk

before=sitediff-before
after=sitediff-after

# paths=
# ifeq ($(paths),failures)
# # NOTE: start.sh getopts parsing will choke on quotes
# #   WRONG: paths_args="-p value"
# #   RIGHT: paths_args=-p value
# paths_arg=-p output/failures.txt
# endif
# ifeq ($(paths),all)
# paths_arg=-p config/coursecal-menu-paths.txt
# endif
# ifeq ($(paths),3)
# paths_arg=-p config/coursecal-menu-paths.top3.txt
# endif


# Tweak the following if your OSX->Vagrant and Vagrant->Docker exposed ports aren't identical
# before_url = http://localhost:$(shell docker port $(before) 80 | awk -F: '{print $$2}' | sed -e 's/4567/8301/' -e 's/4568/8302/' -e 's/4569/8303/')
# after_url  = http://localhost:$(shell docker port $(after)  80 | awk -F: '{print $$2}' | sed -e 's/4567/8301/' -e 's/4568/8302/' -e 's/4569/8303/')

run_sitediff:
	docker run -i -t -rm -p 8888:8888 \
	  -link $(before):before -link $(after):after \
	  -e BEFORE_URL=$(before_url) \
	  -e AFTER_URL=$(after_url) \
	  -v $$(pwd):/var/sitediff \
		dergachev/sitediff \
		/bin/bash /var/sitediff/scripts/start.sh $(paths_arg) $(tests)

sitediff_serve:
	@echo "Serving 'tests/sitediff/output' at http://localhost:8888/report.html"
	cd output/; python -m SimpleHTTPServer 8888

sitediff_clean:
	git clean -fdx tests/sitediff/output/

sitediff: run_sitediff sitediff_serve
