/**
 * client-color-coder
 * 
 * Creates a colored circle SVG file. The color is determined by the folder name passed to the script.
 *
 * @author Corey Salzano <corey@breakfastco.xyz>
 */

// https://stackoverflow.com/a/5624139/338432
function hexToRgb(hex) {
	// Expand shorthand form (e.g. "03F") to full form (e.g. "0033FF")
	var shorthandRegex = /^#?([a-f\d])([a-f\d])([a-f\d])$/i;
	hex = hex.replace(shorthandRegex, function(m, r, g, b) {
	  return r + r + g + g + b + b;
	});
  
	var result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
	return result ? {
	  r: parseInt(result[1], 16),
	  g: parseInt(result[2], 16),
	  b: parseInt(result[3], 16)
	} : null;
}

function hexifyLetter(letter) {
	const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789-'.split('');
	const letterIndex = Math.max(0,alphabet.indexOf(letter.toLowerCase()));
	if ( 16 < letterIndex ) {
		// halve it!
		return hexifyLetter(alphabet[parseInt(letterIndex/2)]);
	}
	if ( letterIndex > 9 ) {
		return alphabet[letterIndex-10];
	}
	return letterIndex;
}

var site = process.argv.slice(2)[0] + 'aaaaaa';
const color = '#' + [site[1],site[3],site[0],site[2],site[4],site[5]].map( hexifyLetter ).join('');
const colorObj = hexToRgb( color );
if ( null !== colorObj ) {
	const rgbCssValue = `rgb(${colorObj.r},${colorObj.g},${colorObj.b})`;
	process.stdout.write('<?xml version="1.0" encoding="UTF-8" standalone="no"?>'
		+ '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">'
		+ '<svg width="100%" height="100%" viewBox="0 0 199 199" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" xml:space="preserve" xmlns:serif="http://www.serif.com/" style="fill-rule:evenodd;clip-rule:evenodd;stroke-linejoin:round;stroke-miterlimit:2;">'
		+ '<circle cx="99.45" cy="99.45" r="99.45" style="fill:' + rgbCssValue + ';"/>'
		+ '</svg>');

}