var tag = require('../build/Release/osx_tag');
var assert = require('assert');
var fs = require('fs');
var os = require('os');
var path = require('path');

var file = path.join(os.tmpdir(), 'osx-tag-null-byte-' + process.pid + '.txt');
var noop = function() {};

describe('null bytes', function() {
    before(function(done) {
        fs.writeFile(file, 'Hello, world.', function(err) {
            if (err) return done(err);
            tag.setTags(file, ['Green'], done);
        });
    });

    it('should reject paths containing null bytes', function() {
        var p = file + '\0.evil';
        assert.throws(function() { tag.getTags(p, noop); }, TypeError);
        assert.throws(function() { tag.setTags(p, ['X'], noop); }, TypeError);
        assert.throws(function() { tag.addTags(p, ['X'], noop); }, TypeError);
        assert.throws(function() { tag.removeTags(p, ['Green'], noop); }, TypeError);
    });

    it('should reject tags containing null bytes', function() {
        assert.throws(function() { tag.setTags(file, ['X\0Y'], noop); }, TypeError);
        assert.throws(function() { tag.addTags(file, ['X\0Y'], noop); }, TypeError);
        assert.throws(function() { tag.removeTags(file, ['Green\0Y'], noop); }, TypeError);
    });

    it('should not modify the truncated-prefix file', function(done) {
        // Give any wrongly queued workers time to run.
        setTimeout(function() {
            tag.getTags(file, function(err, tags) {
                if (err) return done(err);
                assert.deepEqual(tags, ['Green']);
                done();
            });
        }, 100);
    });

    after(function(done) {
        fs.unlink(file, done);
    });
});
