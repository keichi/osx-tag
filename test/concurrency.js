var tag = require('../build/Release/osx_tag');
var assert = require('assert');
var fs = require('fs');
var os = require('os');
var p = require('path');

var path = p.join(os.tmpdir(), 'osx-tag-concurrency-' + process.pid + '.txt');
var N = 50;
var names = [];
for (var i = 0; i < N; i++) names.push('T' + i);

describe('concurrency', function() {
    before(function(done) {
        fs.writeFile(path, 'Hello, world.', function(err) {
            if (err) return done(err);
            tag.setTags(path, [], done);
        });
    });

    it('should keep all tags added concurrently', function(done) {
        var pending = N;
        names.forEach(function(name) {
            tag.addTags(path, [name], function(err) {
                if (err) return done(err);
                if (--pending) return;
                tag.getTags(path, function(err, tags) {
                    if (err) return done(err);
                    assert.deepEqual(tags.sort(), names.slice().sort());
                    done();
                });
            });
        });
    });

    it('should remove all tags removed concurrently', function(done) {
        var pending = N;
        names.forEach(function(name) {
            tag.removeTags(path, [name], function(err) {
                if (err) return done(err);
                if (--pending) return;
                tag.getTags(path, function(err, tags) {
                    if (err) return done(err);
                    assert.deepEqual(tags, []);
                    done();
                });
            });
        });
    });

    after(function(done) {
        fs.unlink(path, done);
    });
});
