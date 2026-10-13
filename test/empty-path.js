var tag = require('../build/Release/osx_tag');
var assert = require('assert');

describe('empty path', function() {
    it('getTags should throw', function() {
        assert.throws(function() { tag.getTags('', function() {}); }, TypeError);
    });
    it('setTags should throw', function() {
        assert.throws(function() { tag.setTags('', ['Red'], function() {}); }, TypeError);
    });
    it('addTags should throw', function() {
        assert.throws(function() { tag.addTags('', ['Red'], function() {}); }, TypeError);
    });
    it('removeTags should throw', function() {
        assert.throws(function() { tag.removeTags('', ['Red'], function() {}); }, TypeError);
    });
});
