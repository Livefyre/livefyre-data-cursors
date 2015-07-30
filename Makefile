.PHONY: test browser package

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

dist:
	mkdir -p dist

dist/livefyre-timeline.js: $(SRC) package.json Makefile | dist
	./node_modules/.bin/browserify . -s LivefyreTimeline > $@

browser: dist/livefyre-timeline.js

.DELETE_ON_ERROR:
