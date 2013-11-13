var tag = require('../build/Release/osx_tag');
var assert = require('assert');

var path = 'test/test.txt';

describe('tag', function() {
    before(function(done) {
        require('fs').writeFile(path, 'Hello, world.', function(err) {
            if (err) return done(err);
            tag.setTags(path, ['Green', 'Red'], function(err) {
                done(err);
            });
        });
    });

    it('should get tags', function(done) {
        tag.getTags(path, function(err, tags) {
            if (err) return done(err);
            assert.deepEqual(tags.sort(), ['Green', 'Red']);
            done();
        });
    });
    it('should add tags', function(done) {
        tag.addTags(path, ['Blue'], function(err) {
            if (err) return done(err);
            tag.getTags(path, function(err, tags) {
                if (err) return done(err);
                assert.deepEqual(tags.sort(), ['Blue', 'Green', 'Red']);
                done();
            });
        });
    });
    it('should remove tags', function(done) {
        tag.removeTags(path, ['Blue'], function(err) {
            if (err) return done(err);
            tag.getTags(path, function(err, tags) {
                if (err) return done(err);
                assert.deepEqual(tags.sort(), ['Green', 'Red']);
                done();
            });
        });
    });

    after(function(done) {
        tag.setTags(path, [], function(err) {
            done(err);
        });
    });
});
