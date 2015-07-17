.PHONY: test

MOCHA_OPTS = --recursive --compilers coffee:coffee-script/register --reporter spec

node_modules: package.json
	npm install
	touch $@

run:
	node bin/www

test:
	node node_modules/.bin/mocha test/ $(MOCHA_OPTS)

debug_test:
	./node_modules/mocha/bin/mocha debug test
