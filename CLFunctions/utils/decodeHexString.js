/* Decodes 16-bit hex string to ASCII */
function decodeHexString(hexString) {
    let str = '';
    for (var i = 0; i < hexString.length; i += 2) {
        str += String.fromCharCode(parseInt(hexString.substr(i, 2), 16));
    }
    return str;
}

module.exports = decodeHexString;
