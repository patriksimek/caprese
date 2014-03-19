# caprese [![NPM version](https://badge.fury.io/js/caprese.png)](http://badge.fury.io/js/caprese) [![Build Status](https://secure.travis-ci.org/patriksimek/caprese.png)](http://travis-ci.org/patriksimek/caprese)

Capped Log for Node.js. A compact library with no dependencies.

Capped logs are fixed-size collections of messages that work in a way similar to circular buffers: once a collection fills its allocated space, it makes room for new messages by overwriting the oldest messages in the collection.

## Installation

    npm install caprese

## Quick Example

```javascript
var Caprese = require('caprese'); 

var config = {size: 1024};
var cap = new Caprese('./log.cap', config);
cap.add(Caprese.INFO, 'My log message.');
```

## Documentation

* [Configuration](#configuration)

### [Caprese](#caprese)

* [add](#add)
* [close](#close)
* [count](#count)
* [select](#select)

### [Query](#query)

* [asc](#asc)
* [desc](#desc)
* [go/toArray](#go)
* [top/limit](#top)
* [where/filter](#where)

<a name="configuration" />
## Configuration

```javascript
var config = {
    overwrite: false,
    resident: true,
    size: 1024
}
```

- **overwrite** - Create new capped log file even if one already exist.
- **resident** - Create new capped log in memory. All data are lost on process exit.
- **size** - Size of capped log file in bytes. Optional. Default value is 1MB. Minimum value is 15 bytes (for one empty message). Maximum value is 4GB.

<a name="caprese" />
## Caprese

Open a capped log. If file doesn't exist, new capped log is created.

__Arguments__

- **file** - Path to capped log file. Optional.
- **config** - Config. Optional.
- **callback(err)** - A callback which is called after capped log has loaded, or an error has occurred. Optional.

__Example__

```javascript
var cap = new Caprese()                                           // create 1MB resident capped log
var cap = new Caprese('./file.cap')                               // create 1MB capped log
var cap = new Caprese('./file.cap', {size: 1024})                 // create 1KB capped log
var cap = new Caprese('./file.cap', {size: 1024}, function() {})  // create 1KB capped log a call a callback function
var cap = new Caprese({size: 1024})                               // create 1KB resident capped log
var cap = new Caprese({size: 1024}, function() {})                // create 1KB resident capped log a call a callback function
var cap = new Caprese(function() {})                              // create 1MB resident capped log a call a callback function
var cap = new Caprese('./file.cap', {size: 1024, resident: true}) // create 1KB resident capped log
```

---------------------------------------

<a name="add" />
### add(type, message, [callback])

Add message to capped log.

__Arguments__

- **type** - Message type (`1` - info, `2` - warning, `3` - error)
- **message** - Message. Max 65535 bytes in utf8 encoding.
- **callback(err)** - A callback which is called after message was saved, or an error has occurred. Optional.

__Example__

```javascript
cap.add(Caprese.ERROR, 'My error message.', function(err) {
    // ...
});
```

---------------------------------------

<a name="close" />
### close()

Close capped log.

__Arguments__

- **callback(err)** - A callback which is called after log has closed, or an error has occurred. Optional.

__Example__

```javascript
cap.close(function(err) {
    // ...
});
```

---------------------------------------

<a name="count" />
### count()

Return number of messages in capped log.

__Example__

```javascript
console.log(cap.count());
```

---------------------------------------

<a name="select" />
### select()

Return Query object to query messages from capped log.

__Example__

```javascript
var query = cap.select();
```

<a name="query" />
## Query

Query messages from capped log. Each method return query, so calls can be chained.

__Example__

```javascript
cap.select().top(1).desc().go(function(err, results) {
	// ...
});
```

---------------------------------------

<a name="asc" />
### asc()

Tell query to return messages in ascending order.

__Example__

```javascript
cap.select().asc();
```

---------------------------------------

<a name="desc" />
### desc()

Tell query to return messages in descending order.

__Example__

```javascript
cap.select().desc();
```

---------------------------------------

<a name="go" />
### go() / toArray()

Return messages.

__Example__

```javascript
cap.select().go(function(err, results) {
	// ...
});
```

---------------------------------------

<a name="top" />
### top() / limit()

Tell query to return only first X messages.

__Arguments__

- **limit** - Limit of messages to return.

__Example__

```javascript
cap.select().top(limit);
```

---------------------------------------

<a name="where" />
### where() / filter()

Tell query to filter messages.

__Arguments__

- **condition** - Key-value collection. Only type filter is available atm.

__Example__

```javascript
cap.select().where({type: Caprese.ERROR});
```

<a name="license" />
## License

Copyright (c) 2014 Patrik Simek

The MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
