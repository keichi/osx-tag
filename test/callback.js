var tag = require('../build/Release/osx_tag');
var assert = require('assert');
var fs = require('fs');
var os = require('os');
var path = require('path');

var file = path.join(os.tmpdir(), 'osx-tag-callback-test.txt');

describe('callback', function() {
    before(function() {
        fs.writeFileSync(file, 'Hello, world.');
    });
    after(function() {
        fs.unlinkSync(file);
    });

    ['setTags', 'addTags', 'removeTags'].forEach(function(name) {
        it(name + ' should throw without a callback', function() {
            assert.throws(function() { tag[name](file, ['A']); }, TypeError);
        });
    });
});
