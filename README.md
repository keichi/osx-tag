# osx-tag

This is a node.js package that allows you to operate tags associated with
files on macOS. Works only on macOS 10.9 (Mavericks) or later.

## Quick Start

```shell
$ npm install osx-tag
```

Simple example:

```javascript
var tag = require('osx-tag');
var path = 'foo.txt';

tag.getTags(path, function(err, tags) {
    if (err) throw err;
    console.log(tags);
    tag.addTags(path, ['Important', 'Photo'], function(err) {
        if (err) throw err;
    });
});
```

## API

See `test/test.js` for usage.

### getTags(path, callback)
- `path` - Path of the file/directory to retrieve associated tags.
- `callback` - This callback function is called with  two arguments
    `(err, tags)` where `tags` is an array of tags.

### setTags(path, tags, callback)
- `path` - Path of the file/directory to set tags.
- `tags` - Array of tags to assign.
- `callback` - This callback is called with one argument `(err)`.

### addTags(path, tags, callback)
- `path` - Path of the file/directory to add tags.
- `tags` - Array of tags to add.
- `callback` - This callback is called with one argument `(err)`.

### removeTags(path, tags, callback)
- `path` - Path of the file/directory to remove tags.
- `tags` - Array of tags to remove.
- `callback` - This callback is called with one argument `(err)`.
