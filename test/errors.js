var tag = require('../build/Release/osx_tag');
var assert = require('assert');

var missing = 'test/does-not-exist.txt';

describe('errors', function() {
    it('getTags should fail on a nonexistent path', function(done) {
        tag.getTags(missing, function(err) {
            assert.ok(err instanceof Error);
            done();
        });
    });
    it('setTags should fail on a nonexistent path', function(done) {
        tag.setTags(missing, ['Red'], function(err) {
            assert.ok(err instanceof Error);
            done();
        });
    });
    it('addTags should fail on a nonexistent path', function(done) {
        tag.addTags(missing, ['Red'], function(err) {
            assert.ok(err instanceof Error);
            done();
        });
    });
    it('removeTags should fail on a nonexistent path', function(done) {
        tag.removeTags(missing, ['Red'], function(err) {
            assert.ok(err instanceof Error);
            done();
        });
    });
});
