var tag = require('../build/Release/osx_tag');
var assert = require('assert');

var path = 'test/test.txt';
var noop = function() {};

describe('non-string tags', function() {
    ['setTags', 'addTags', 'removeTags'].forEach(function(fn) {
        [[1], [null], ['a', {}]].forEach(function(tags) {
            it(fn + ' should throw TypeError for ' + JSON.stringify(tags), function() {
                assert.throws(function() {
                    tag[fn](path, tags, noop);
                }, TypeError);
            });
        });
    });
});
