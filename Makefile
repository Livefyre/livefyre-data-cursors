.PHONY: test browser package dist

THIS_FILE := $(lastword $(MAKEFILE_LIST))
MOCHA_OPTS = --recursive --compilers coffee:coffee-script/register --reporter spec
SRC = $(shell find lib/ -type f)


node_modules: package.json
	npm install
	touch $@

run:
	node bin/www

test:
	node node_modules/.bin/mocha test/ $(MOCHA_OPTS)

server:
	python -m SimpleHTTPServer 5000
#	open public/test-dist.html

debug_test:
	./node_modules/mocha/bin/mocha debug test

package: browser

package_loop:
	watch -n 2 $(MAKE) package

dist: dist/timeline-jslib.js dist/timeline-jslib.lf.js

dist/timeline-jslib.js: $(SRC) package.json Makefile
	mkdir -p dist
	./node_modules/.bin/browserify . -s LivefyreTimeline > $@

dist/timeline-jslib.lf.js: dist/timeline-jslib.js tools/*
	mkdir -p dist
	cat tools/wrap-start.frag $< tools/wrap-end.frag \
	> $@

browser: dist/timeline-jslib.js

.DELETE_ON_ERROR:
