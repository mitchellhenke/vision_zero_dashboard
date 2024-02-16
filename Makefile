.PHONY: install build dev
install:
	cd assets && npm install
dev:
	cd assets && npx esbuild --minify js/index.js --bundle --target=es2017 --outdir=./../_public/js/ --watch=forever &
	cd _public && python3 -m http.server 9000
	npx gulp watch
