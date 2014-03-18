fs = require 'fs'
assert = require 'assert'
Caprese = require '..'

FILE = "#{__dirname}/_test.cap"

ca = null

describe 'Writes', ->
	before (done) ->
		fs.unlink FILE, -> done()
		
	it 'should create 100 byte capped log', (done) ->
		ca = new Caprese FILE, {size: 100}, (err) ->
			if err then return done err
			
			stats = fs.statSync FILE
			assert.equal ca.size, 88 # - 12 byte header
			assert.equal stats.size, 100
			
			assert.equal ca.first, 0
			assert.equal ca.cursor, 0
			assert.equal ca.index.length, 0
			
			done()
			
	
	it 'should add one entry to log', (done) ->
		ca.add 0x01, 'Mess', (err) -> # 4 + 3
			if err then return done err
			
			assert.equal ca.count(), 1
			ca.select().go (err, result) ->
				if err then return done err
				
				assert.equal result.length, 1
				assert.equal result[0].type, 0x01
				assert.equal result[0].message, 'Mess'
				
				assert.equal ca.first, 0
				assert.equal ca.cursor, 7
				assert.equal ca.index[0].offset, 3
				assert.equal ca.index[0].length, 4
			
				done()
	
	it 'should add empty message', (done) ->
		ca.add 0x01, '', (err) -> # 0 + 3
			if err then return done err

			assert.equal ca.count(), 2
			ca.select().go (err, result) ->
				if err then return done err

				assert.equal result.length, 2
				assert.equal result[1].type, 0x01
				assert.equal result[1].message, ''
				
				assert.equal ca.first, 0
				assert.equal ca.cursor, 10
				assert.equal ca.index[1].offset, 10
				assert.equal ca.index[1].length, 0
			
				done()
	
	it 'should add two more entries to log', (done) ->
		ca.add 0x02, '............z..............', (err) -> # 27 + 3
			if err then return done err

			assert.equal ca.count(), 3
			ca.select().go (err, result) ->
				if err then return done err

				assert.equal result.length, 3
				assert.equal result[2].type, 0x02
				assert.equal result[2].message, '............z..............'
				
				assert.equal ca.first, 0
				assert.equal ca.cursor, 40
				assert.equal ca.index[2].offset, 13
				assert.equal ca.index[2].length, 27

				ca.add 0x02, 'x...........................................x', (err) -> # 45 + 3
					if err then return done err

					assert.equal ca.count(), 4
					ca.select().go (err, result) ->
						if err then return done err
		
						assert.equal result.length, 4
						assert.equal result[3].type, 0x02
						assert.equal result[3].message, 'x...........................................x'
				
						assert.equal ca.first, 0
						assert.equal ca.cursor, 0
						assert.equal ca.index[3].offset, 43
						assert.equal ca.index[3].length, 45
					
						done()
	
	it 'should add one small entry and delete first one', (done) ->
		ca.add 0x01, '-', (err) -> # 1 + 3
			if err then return done err

			assert.equal ca.count(), 4
			ca.select().go (err, result) ->
				assert.equal result.length, 4
				assert.equal result[0].type, 0x01
				assert.equal result[0].message, ''
				assert.equal result[1].type, 0x02
				assert.equal result[1].message, '............z..............'
				assert.equal result[2].type, 0x02
				assert.equal result[2].message, 'x...........................................x'
				assert.equal result[3].type, 0x01
				assert.equal result[3].message, '-'
				
				assert.equal ca.first, 7
				assert.equal ca.cursor, 4
				assert.equal ca.index[3].offset, 3
				assert.equal ca.index[3].length, 1

				done()
	
	it 'should add one small entry to fill blank space', (done) ->
		ca.add 0x01, 'aaa', (err) -> # 3 + 3
			if err then return done err

			assert.equal ca.count(), 4
			ca.select().go (err, result) ->
				if err then return done err

				assert.equal result.length, 4
				assert.equal result[0].type, 0x02
				assert.equal result[0].message, '............z..............'
				assert.equal result[1].type, 0x02
				assert.equal result[1].message, 'x...........................................x'
				assert.equal result[2].type, 0x01
				assert.equal result[2].message, '-'
				assert.equal result[3].type, 0x01
				assert.equal result[3].message, 'aaa'
				
				assert.equal ca.first, 10
				assert.equal ca.cursor, 10
				assert.equal ca.index[3].offset, 7
				assert.equal ca.index[3].length, 3

				done()
	
	it 'should fill almost all db and leave just one last record', (done) ->
		ca.add 0x02, 'iiiiiiiiiiiiiiieiiiiiiiiiiiiiiiiiiiwiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiieiiiiiii', (err) -> # 79 + 3
			if err then return done err

			assert.equal ca.count(), 2
			ca.select().go (err, result) ->
				if err then return done err

				assert.equal result.length, 2
				assert.equal result[0].type, 0x01
				assert.equal result[0].message, 'aaa'
				assert.equal result[1].type, 0x02
				assert.equal result[1].message, 'iiiiiiiiiiiiiiieiiiiiiiiiiiiiiiiiiiwiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiieiiiiiii'
				
				assert.equal ca.first, 4
				assert.equal ca.cursor, 4
				assert.equal ca.index[0].offset, 7
				assert.equal ca.index[0].length, 3
				assert.equal ca.index[1].offset, 13
				assert.equal ca.index[1].length, 79

				done()
	
	it 'should fill whole db with one record', (done) ->
		ca.add 0x01, 'iiiiiiiiiiiiiiieiiiiiiiiiiiiiiiiiiiwiiiiiiiiiiiiiiiiiiiddddddiiiiiiiiiiiiiiiieiiiiiii', (err) -> # 85 + 3
			if err then return done err

			assert.equal ca.count(), 1
			ca.select().go (err, result) ->
				if err then return done err

				assert.equal result.length, 1
				assert.equal result[0].type, 0x01
				assert.equal result[0].message, 'iiiiiiiiiiiiiiieiiiiiiiiiiiiiiiiiiiwiiiiiiiiiiiiiiiiiiiddddddiiiiiiiiiiiiiiiieiiiiiii'
				
				assert.equal ca.first, 4
				assert.equal ca.cursor, 4
				assert.equal ca.index[0].offset, 7
				assert.equal ca.index[0].length, 85

				done()
	
	it 'should add one small entry and delete the big one', (done) ->
		ca.add 0x01, ':)', (err) -> # 2 + 3
			if err then return done err

			assert.equal ca.count(), 1
			ca.select().go (err, result) ->
				if err then return done err
				
				assert.equal result.length, 1
				assert.equal result[0].type, 0x01
				assert.equal result[0].message, ':)'
				
				assert.equal ca.first, 4
				assert.equal ca.cursor, 9
				assert.equal ca.index[0].offset, 7
				assert.equal ca.index[0].length, 2

				done()
	
	it 'should add last three entries to log', (done) ->
		ca.add 0x02, '............z..............', (err) -> # 27 + 3
			if err then return done err

			assert.equal ca.count(), 2
			ca.select().go (err, result) ->
				if err then return done err

				assert.equal result.length, 2
				assert.equal result[1].type, 0x02
				assert.equal result[1].message, '............z..............'
				
				assert.equal ca.first, 4
				assert.equal ca.cursor, 39
				assert.equal ca.index[1].offset, 12
				assert.equal ca.index[1].length, 27

				ca.add 0x02, 'x...........................................x', (err) -> # 45 + 3
					if err then return done err

					assert.equal ca.count(), 3
					ca.select().go (err, result) ->
						if err then return done err
		
						assert.equal result.length, 3
						assert.equal result[2].type, 0x02
						assert.equal result[2].message, 'x...........................................x'
				
						assert.equal ca.first, 4
						assert.equal ca.cursor, 87
						assert.equal ca.index[2].offset, 42
						assert.equal ca.index[2].length, 45

						ca.add 0x01, ':(', (err) -> # 2 + 3
							if err then return done err
		
							assert.equal ca.count(), 4
							ca.select().go (err, result) ->
								if err then return done err
				
								assert.equal result.length, 4
								assert.equal result[3].type, 0x01
								assert.equal result[3].message, ':('
						
								assert.equal ca.first, 4
								assert.equal ca.cursor, 4
								assert.equal ca.index[3].offset, 2
								assert.equal ca.index[3].length, 2
							
								done()

	it 'should fail because entry is larger then db', (done) ->
		ca.add 0x01, '......................................................................................', (err) -> # 86 + 3
			assert err instanceof Error
			assert /Message \(86 bytes\) is larger than db limit of 85 bytes/.exec err.message
			
			done null
	
	after: (done) ->
		ca.close done

describe 'Reads', ->
	before (done) ->
		ca = new Caprese FILE, done
		
	it 'should load db', (done) ->
		stats = fs.statSync FILE
		assert.equal ca.size, 88 # - 12 byte header
		assert.equal stats.size, 100
		
		assert.equal ca.count(), 4
		ca.select().go (err, result) ->
			if err then return done err

			assert.equal result.length, 4
			assert.equal result[0].type, 0x01
			assert.equal result[0].message, ':)'
			assert.equal result[1].type, 0x02
			assert.equal result[1].message, '............z..............'
			assert.equal result[2].type, 0x02
			assert.equal result[2].message, 'x...........................................x'
			assert.equal result[3].type, 0x01
			assert.equal result[3].message, ':('
			
			assert.equal ca.first, 4
			assert.equal ca.cursor, 4
			assert.equal ca.index[0].offset, 7
			assert.equal ca.index[0].length, 2
			
			done()
	
	after: (done) ->
		ca.close done

describe 'Stress', ->
	before (done) ->
		fs.unlink FILE, -> done()
		
	it 'should write 10000 entries', (done) ->
		ca = new Caprese FILE, {size: 1024}, (err) ->
			if err then return done err
			
			stats = fs.statSync FILE
			assert.equal ca.size, 1012 # - 12 byte header
			assert.equal stats.size, 1024
			
			complete = 0
			for i in [1..10000]
				ca.add 0x01, '-T-E-S-T-M-E-S-S-A-G-E-', (err) ->
					if err then return done err
					
					if ++complete is 10000
						assert.equal ca.count(), 38
						ca.select().go (err, result) ->
							if err then return done err
							
							assert.equal result.length, 38
							
							for item in result
								assert.equal item.type, 0x01
								assert.equal item.message, '-T-E-S-T-M-E-S-S-A-G-E-'
							
							done()
	
	after: (done) ->
		ca.close done

first = null
last = null

describe 'Queries', ->
	before (done) ->
		fs.unlink FILE, ->
			ca = new Caprese FILE, {size: 1024}, (err) ->
				if err then return done err
				
				complete = 0
				
				int = setInterval ->
					date = Date.now()
					unless first then first = date
					
					ca.add 0x01, date, (err) ->
						if err then return done err
						
						if ++complete is 50
							last = date
							clearInterval int
							done()
				
				, 1
		
	it 'should return most recent entry', (done) ->
		assert.equal ca.count(), 50
		
		ca.select().top(1).desc().go (err, result) ->
			if err then return done err
			
			assert.equal result[0].message, last
			
			ca.select().top(10).asc().go (err, result) ->
				if err then return done err

				assert.equal result.length, 10
				assert.equal result[0].message, first
			
				done()
	
	after: (done) ->
		ca.close done