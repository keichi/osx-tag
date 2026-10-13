var tag = require('../build/Release/osx_tag');
var assert = require('assert');

var path = 'test/test.txt';

describe('throwing getter in tags array', function() {
    ['setTags', 'addTags', 'removeTags'].forEach(function(fn) {
        it(fn + ' should rethrow the getter error', function() {
            var a = ['x'];
            Object.defineProperty(a, 0, { get: function() { throw new Error('g'); } });
            assert.throws(function() { tag[fn](path, a, function() {}); }, /g/);
        });
    });
});
