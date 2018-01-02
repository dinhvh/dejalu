all: minified-js minified-css

minified-js: composer-view.min.js highlighter.min.js html-cleaning.min.js \
	conversation-selection-view.min.js objc-glue.min.js \
	conversation-view2.min.js uuid.min.js add-account.min.js \
	create-link.min.js signature.min.js print-message-view.min.js \
	spin.min.js

minified-css: add-account.min.css conversation-view.min.css \
	composer-view.min.css print-message-view.min.css \
	conversation-selection-view.min.css signature.min.css

%.min.js: %.js
	/usr/local/bin/uglifyjs $< -m -c -o $@ --source-map filename=$<.map

%.min.css: %.css
	/usr/local/bin/cleancss -o $@ $<
