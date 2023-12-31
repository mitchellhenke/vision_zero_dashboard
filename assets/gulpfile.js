/* gulpfile.js */

/**
* Import uswds-compile
*/
const uswds = require("@uswds/compile");

/**
* USWDS version
* Set the major version of USWDS you're using
* (Current options are the numbers 2 or 3)
*/
uswds.settings.version = 3;

/**
* Path settings
* Set as many as you need
*/
uswds.paths.dist.css = '../_public/css';
uswds.paths.dist.fonts = '../_public/fonts'
uswds.paths.dist.img = '../_public/img'
uswds.paths.dist.js = '../_public/js'
uswds.paths.dist.theme = './sass/uswds';

/**
* Exports
* Add as many as you need
*/
exports.init = uswds.init;
exports.compile = uswds.compile;
exports.watch = uswds.watch;
exports.copyFonts = uswds.copyFonts;
exports.copyImages = uswds.copyImages
exports.copyJS = uswds.copyJS
