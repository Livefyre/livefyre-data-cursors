.PHONY: test browser package dist

THIS_FILE := $(lastword $(MAKEFILE_LIST))
MOCHA_OPTS = --recursive --compilers coffee:coffee-script/register --reporter spec
SRC = $(shell find lib/ -type f)

UGLIFY=./node_modules/.bin/uglifyjs

package: browser

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


package_loop:
	watch -n 2 $(MAKE) package

dist: dist/livefyre-data-cursors.js dist/livefyre-data-cursors.lf.js dist/livefyre-data-cursors.lf.min.js

dist/livefyre-data-cursors.js: $(SRC) package.json Makefile
	mkdir -p dist
	./node_modules/.bin/browserify . -s LivefyreDataCursors > $@

dist/livefyre-data-cursors.lf.js: dist/livefyre-data-cursors.js tools/*
	mkdir -p dist
	cat tools/wrap-start.frag $< tools/wrap-end.frag \
	> $@

dist/livefyre-data-cursors.lf.min.js: dist/livefyre-data-cursors.lf.js
	mkdir -p dist
	$(UGLIFY) $< --source-map $@.map -p relative -o $@

browser: dist

.DELETE_ON_ERROR:
