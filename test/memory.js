var assert = require('assert');
var childProcess = require('child_process');
var fs = require('fs');
var os = require('os');
var path = require('path');

describe('memory', function() {
    this.timeout(30000);

    it('should not leak when calling getTags repeatedly', function() {
        var file = path.join(os.tmpdir(), 'osx-tag-memory-' + process.pid + '.txt');
        fs.writeFileSync(file, 'Hello, world.');

        var script = [
            'var tag = require(' + JSON.stringify(path.resolve(__dirname, '../build/Release/osx_tag')) + ');',
            'var file = ' + JSON.stringify(file) + ';',
            'var n = 0, start;',
            '(function next() {',
            '    tag.getTags(file, function(err) {',
            '        if (err) throw err;',
            '        if (++n === 5000) start = process.memoryUsage().rss;',
            '        if (n < 55000) return next();',
            '        console.log(process.memoryUsage().rss - start);',
            '    });',
            '})();'
        ].join('\n');

        try {
            var res = childProcess.spawnSync(process.execPath, ['-e', script], {encoding: 'utf8'});
            assert.strictEqual(res.status, 0, res.stderr);
            var growth = parseInt(res.stdout, 10);
            assert(growth < 20 * 1024 * 1024, 'RSS grew by ' + (growth / 1024 / 1024).toFixed(1) + ' MB');
        } finally {
            fs.unlinkSync(file);
        }
    });
});
