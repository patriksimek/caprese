return;

var fs = require('fs');

var Caprese = require('..');

var options = {
	size: 1024 * 1024
};

var ITERATIONS = 10000;

function test1() {
	var cap = new Caprese(__dirname +'/stress1.cap', options, function(err) {
		if (err) return console.error(err);
		
		console.log("Starting test 1");
	
		var done = 0
		console.time('queued messages');
	
		for (var i = 0; i < ITERATIONS; i++) {
			cap.add(1, 'Test log message.', function(err) {
				if (err) console.error(err);
				done++;
	
				if (done == ITERATIONS) {
					console.timeEnd('queued messages')
					
					setTimeout(function() { test2(); }, 500);
				};
			});
		};
	});
};

function test2() {
	var ws = fs.createWriteStream(__dirname +'/stress2.txt');
	
	var done = 0
	console.time('writestream');
	
	for (var i = 0; i < ITERATIONS; i++) {
		ws.write('Test log message.', 'utf8', function(err) {
			if (err) console.error(err);
			done++;
	
			if (done == ITERATIONS) {
				console.timeEnd('writestream')
					
				setTimeout(function() { test3(); }, 500);
			};
		});
	};
};

function test3() {
	var file = __dirname +'/stress3.txt';

	console.time('appendfile');
	
	for (var i = 0; i < ITERATIONS; i++) {
		fs.appendFileSync(file, 'Test log message.');
	};
	
	console.timeEnd('appendfile')
};

test1();