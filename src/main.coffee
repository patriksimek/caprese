fs = require 'fs'
Query = require './query'

HEADER_SIZE = 12
# 0 - 0x63 (c)
# 1 - 0x61 (a)
# 2 - 0x70 (p)
# 3 - 0x01 (version)
# 4-7 - 0x00000000 (cursor)
# 8-11 - 0x00000000 (first)

ENTRY_TYPE_LENGTH = 1
ENTRY_LENGTH_LENGTH = 2
ENTRY_HEADER_LENGTH = ENTRY_TYPE_LENGTH + ENTRY_LENGTH_LENGTH
DB_MIN_SIZE = ENTRY_HEADER_LENGTH
DB_MAX_SIZE = 4294967295
MAX_MESSAGE_SIZE = 65535
NOOP = ->

DEFAULT_SIZE = 1024 * 1024

class Caprese
	fd: null
	db: null # resident capped log
	size: 0
	index: null
	first: null
	lock: true
	queued: null
	
	_closeOnDone: false
	
	@INFO: 0x01
	@ERROR: 0x02
	@WARNING: 0x03
	
	###
	new Caprese() 											- create 1MB resident capped log
	new Caprese('./file.cap')								- create 1MB capped log
	new Caprese('./file.cap', {size: 1024})					- create 1KB capped log
	new Caprese('./file.cap', {size: 1024}, function() {})	- create 1KB capped log and call a callback function
	new Caprese({size: 1024})								- create 1KB resident capped log
	new Caprese({size: 1024}, function() {})				- create 1KB resident capped log and call a callback function
	new Caprese(function() {})								- create 1MB resident capped log and call a callback function
	new Caprese('./file.cap', {size: 1024, resident: true})	- create 1KB resident capped log
	###
	
	constructor: ->
		@index = []
		@queued = []
		
		if arguments.length
			if typeof arguments[0] is 'string'
				@file = arguments[0]
				
				if arguments.length > 1
					if typeof arguments[1] is 'object'
						@options = arguments[1]
						
						if arguments.length > 2
							if typeof arguments[2] is 'function'
								callback = arguments[2]
								
								if arguments.length > 3
									throw new Error "Invalid arguments."
							
							else
								throw new Error "Invalid arguments."
						
						else
							callback = NOOP
						
					else if typeof arguments[1] is 'function'
						@options =
							size: DEFAULT_SIZE
						callback = arguments[1]
					
					else
						throw new Error "Invalid arguments."
				
				else
					@options =
						size: DEFAULT_SIZE
					callback = NOOP
			
			else if typeof arguments[0] is 'object'
				@options = arguments[0]
				
				if arguments.length > 1
					if typeof arguments[1] is 'function'
						callback = arguments[1]
						
						if arguments.length > 2
							throw new Error "Invalid arguments."
					
					else
						throw new Error "Invalid arguments."
				
				else
					callback = NOOP
			
			else if typeof arguments[0] is 'function'
				callback = arguments[0]
				
				@options =
					size: DEFAULT_SIZE
					resident: true
				
				if arguments.length > 1
					throw new Error "Invalid arguments."
			
			else
				throw new Error "Invalid arguments."
		
		# ---
		
		else
			@options =
				size: DEFAULT_SIZE
				resident: true
			callback = NOOP
		
		if arguments.length is 0
			@options =
				resident: true
				size: 1024 * 1024
			callback = NOOP
		
		else if arguments.length is 1
			if arguments[0] instanceof Function
				@options =
					resident: true
					size: 1024 * 1024
				callback = arguments[0]
			
			else if typeof arguments[0] is 'string'
				@file = arguments[0]
				@options =
					resident: true
					size: 1024 * 1024
				callback = NOOP
		
		if @options instanceof Function
			callback = @options
			@options = DEFAULT_OPTIONS
		
		@options ?= DEFAULT_OPTIONS
		callback ?= NOOP
		
		if @options.resident
			@create null, callback
		
		else
			if @options.overwrite
				@create @file, callback
			
			else
				fs.exists @file, (exist) =>
					if exist
						fs.open @file, 'r+', (err, @fd) =>
							if err then return callback err
							
							@load callback
						
					else
						@create @file, callback
	
	_diff: (from, to) ->
		if to > from
			return to - from
		else if to < from
			to + (@size - from)
		else
			0
	
	_move: (offset, length) ->
		next = offset + length
		
		if length > 0
			if next >= @size then next = next - @size
		else
			if next < 0 then next = @size + next
		
		next
	
	add: (type, message, callback = NOOP) ->
		if @lock
			return @queue type, message, callback
		
		unless typeof message is 'string' then message = String message
		length = Buffer.byteLength message, 'utf8'
		
		if length + ENTRY_HEADER_LENGTH > @size
			return callback new Error "Message (#{length} bytes) is larger than db limit of #{@size - ENTRY_HEADER_LENGTH} bytes"
			
		if length > MAX_MESSAGE_SIZE
			return callback new Error "Message (#{length} bytes) is larger than entry limit of #{MAX_MESSAGE_SIZE} bytes"
			
		@lock = true
		
		buffer = new Buffer length + ENTRY_HEADER_LENGTH
		buffer.writeUInt8 type, 0
		buffer.writeUInt16LE length, 1
		if length then buffer.write message, 3, length, 'utf8'

		@clear buffer.length, (err) =>
			if err
				@lock = false
				return callback err
				
			@write buffer, @cursor, (err, nextbyte) =>
				if err
					@lock = false
					return callback err
				
				# update cursor in file header	
				buffer = new Buffer 4
				buffer.writeUInt32LE nextbyte, 0
				@_write buffer, 0, 4, @size + 4, (err) =>
					if err
						@lock = false
						return callback err
					
					@index.push
						offset: @_move @cursor, ENTRY_HEADER_LENGTH
						length: length
						type: type

					@cursor = nextbyte
					@lock = false
					
					@unqueue()
					
					callback? null
	
	clear: (length, callback) ->
		unless @index.length then return callback null
		
		#console.log "CLEAR need:", length, "got:", @_diff(@cursor, @_move(@index[0].offset, -ENTRY_HEADER_LENGTH))
		#console.log "from:", @cursor, "to:", @_move(@index[0].offset, -ENTRY_HEADER_LENGTH)
		
		edit = false
		while @index.length and @_diff(@cursor, @_move(@index[0].offset, -ENTRY_HEADER_LENGTH)) < length
			#console.log "REMOVING"
			edit = true
			@index.shift()
		
		unless edit then return callback null
		
		if @index.length
			first = @_move(@index[0].offset, -ENTRY_HEADER_LENGTH)
		else
			first = @cursor
		
		# update first in file header
		buffer = new Buffer 4
		buffer.writeUInt32LE first, 0
		@_write buffer, 0, 4, @size + 8, (err) =>
			if err then return callback null
			
			@first = first
			
			callback null
	
	close: (callback = NOOP) ->
		if @lock
			@_closeOnDone = callback ? true
			return
		
		else
			@first = 0
			@cursor = 0
			@index = []
			@queued = []
			@lock = true
			
			if @fd
				fs.close @fd, callback
				@fd = null
			else if @db
				@db = null
				process.nextTick => callback null
	
	count: ->
		@index.length
	
	_create: (size, callback) ->
		# first byte must be 0x00, we dont care about the rest of the file
		buffer = new Buffer [0x00]
		@_write buffer, 0, 1, 0, (err) =>
			if err then return callback err

			buffer = new Buffer HEADER_SIZE
			buffer.fill 0x00
			buffer.write 'cap', 0, 3, 'ascii'
			buffer.writeUInt8 1, 3
			buffer.writeUInt32LE 0, 4
			buffer.writeUInt32LE 0, 4
			
			@_write buffer, 0, HEADER_SIZE, size, (err) =>
				if err then return callback err
			
				@load callback
	
	create: (file, callback) ->
		size = @options.size - HEADER_SIZE
		
		if size < DB_MIN_SIZE
			return callback new Error "Minimum size is #{DB_MIN_SIZE + HEADER_SIZE}"
		
		if size > DB_MAX_SIZE
			return callback new Error "Maximum size is #{DB_MAX_SIZE + HEADER_SIZE}"
			
		if @options.resident
			process.nextTick =>
				try
					@db = new Buffer @options.size
					@_create size, callback
					
				catch ex
					callback ex

		else
			fs.open file, 'w+', (err, @fd) =>
				if err then return callback err
				
				@_create size, callback
	
	load: (callback) ->
		if @fd
			fs.fstat @fd, (err, stats) =>
				if err then return callback err
				
				@size = stats.size - HEADER_SIZE
				if @size < DB_MIN_SIZE
					return callback new Error "Invalid cap file (SIZE:#{stats.size})"
		
				header = new Buffer HEADER_SIZE
				@_read header, 0, HEADER_SIZE, @size, (err) =>
					if err then return callback err
	
					unless header[0] is 0x63 and header[1] is 0x61 and header[2] is 0x70
						return callback new Error "Invalid cap file (HEADER)"
					
					unless header[3] is 0x01
						return callback new Error "Invalid cap file (VERSION)"
					
					@cursor = header.readUInt32LE 4
					if @cursor >= @size
						return callback new Error "Invalid cap file (CURSOR)"
					
					@first = header.readUInt32LE 8
					if @first >= @size
						return callback new Error "Invalid cap file (FIRST)"
					
					@reindex (err) =>
						if err then return callback err
						
						@lock = false
						@unqueue()
						callback null
		
		else if @db
			process.nextTick =>
				@size = @db.length - HEADER_SIZE
				@cursor = 0
				@first = 0
				@lock = false
				@unqueue()
				callback null
		
		else
			process.nextTick -> callback new Error "Failed to load database"
	
	queue: (type, message, callback) ->
		@queued.push
			type: type
			message: message
			callback: callback
	
	unqueue: ->
		if @queued.length
			msg = @queued.shift()
			@add msg.type, msg.message, msg.callback
		
		else
			if @_closeOnDone
				@close @_closeOnDone
				return
	
	select: ->
		new Query @
		
	stats: ->
		console.log "Size:", @size
		console.log "First:", @first
		console.log "Cursor:", @cursor
		console.log "Index:", @index
		
		if @fd
			console.log "Buffer:", new Buffer fs.readFileSync @file, 'binary'
		else if @db
			console.log "Buffer:", @db
	
	_read: (buffer, offset, length, position, callback) ->
		if @fd
			fs.read @fd, buffer, offset, length, position, callback
		
		else if @db
			process.nextTick =>
				try
					@db.copy buffer, offset, position, position + length
					callback null
				catch ex
					callback ex
		
		else
			process.nextTick -> callback new Error "No database is initialized."
	
	read: (offset, length, callback) ->
		if length > @size
			return callback new RangeError "Reading more data than size of capped file"
			
		if offset < 0 or offset >= @size
			return callback new Error "Out of bounds"
		
		# precalculate next byte after selected chunk
		next = @_move offset, length

		buffer = new Buffer length
		
		# just to imagine everything :)
		# offset = 90
		# length = 20
		# size = 100

		if offset + length > @size
			# read is splitted
			part = @size - offset
			
			@_read buffer, 0, part, offset, (err) =>
				if err then return callback err

				@_read buffer, part, (length - part), 0, (err) => callback err, buffer, next
		
		else
			@_read buffer, 0, length, offset, (err) => callback err, buffer, next
	
	reindex: (callback) ->
		buffer = new Buffer 1
		cursor = @first
		eof = false
		
		test = -> eof
		fn = (next) =>
			@read cursor, 1, (err, buffer, nextbyte) =>
				if err then return next err

				if buffer[0] is 0x00
					eof = true
					next null
				
				else if buffer[0] is Caprese.INFO or buffer[0] is Caprese.ERROR or buffer[0] is Caprese.WARNING
					type = buffer.readUInt8 0
					cursor = nextbyte

					@read cursor, 2, (err, buffer, nextbyte) =>
						if err then return next err
						
						length = buffer.readUInt16LE 0
						@index.push
							offset: nextbyte
							length: length
							type: type
						
						cursor = @_move nextbyte, length
						if cursor is @cursor
							eof = true
						
						next null
				
				else
					next new Error "Unknown type '#{buffer[0]}' on offset '#{cursor}'"
		
		cb = (err) ->
			if err then return callback err
			unless eof then return fn cb
			callback null
		
		fn cb
	
	_write: (buffer, offset, length, position, callback) ->
		if @fd
			fs.write @fd, buffer, offset, length, position, callback
		
		else if @db
			process.nextTick =>
				try
					buffer.copy @db, position, offset, offset + length
					callback null
				catch ex
					callback ex
		
		else
			process.nextTick -> callback new Error "No database is initialized."
	
	write: (buffer, offset, callback) ->
		if buffer.length > @size
			return callback new RangeError "Writing more data than size of capped file"
			
		if offset < 0 or offset >= @size
			return callback new Error "Out of bounds"
		
		# precalculate next byte after selected chunk
		next = @_move offset, buffer.length
		
		if offset + buffer.length > @size
			# write is splitted
			part = @size - offset
			
			@_write buffer, 0, part, offset, (err) =>
				if err then return callback err
			
				@_write buffer, part, (buffer.length - part), 0, (err) => callback err, next
		
		else			
			@_write buffer, 0, buffer.length, offset, (err) => callback err, next

module.exports = Caprese