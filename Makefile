.PHONY: test browser

MOCHA_OPTS = --recursive --compilers coffee:coffee-script/register --reporter spec
SRC = $(wildcard lib/*)

node_modules: package.json
	npm install
	touch $@

run:
	node bin/www

test:
	node node_modules/.bin/mocha test/ $(MOCHA_OPTS)

debug_test:
	./node_modules/mocha/bin/mocha debug test

dist:
	mkdir -p dist

dist/livefyre-timeline.js: dist $(SRC) Makefile
	./node_modules/.bin/browserify . -s LivefyreTimeline > dist/livefyre-timeline.js

browser: dist/livefyre-timeline.js
