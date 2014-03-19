class Query
	_limit: 0
	_order: 'asc'
	_type: null
	
	constructor: (@log) ->
		
	
	asc: ->
		@_order = 'asc'
		@
	
	desc: ->
		@_order = 'desc'
		@
	
	filter: (condition) ->
		if condition?.type?
			@_type = condition.type
		@
	
	go: (callback) ->
		filter = @log.index.slice 0
		if @_type? then filter = filter.filter (item) => item.type is @_type
		if @_order is 'desc' then filter.reverse()
		if @_limit > 0 then filter.splice @_limit, filter.length - @_limit
		
		cd = filter.length
		cb = false
		re = []
		
		if cd is 0 then return callback null, re

		for item, index in filter
			if cb then break
			
			do (item, index) =>
				if item.length is 0
					re[index] =
						type: item.type
						message: ''
	
					if --cd is 0
						cb = true
						callback null, re
				
				else
					@log.read item.offset, item.length, (err, buffer) =>
						if cb then return
						if err
							cb = true
							return callback err
						
						re[index] =
							type: item.type
							message: buffer.toString()
		
						if --cd is 0
							cb = true
							callback null, re

		@
	
	limit: (count) ->
		@_limit = count
		@
	
	top: (count) ->
		@limit count
	
	toArray: (callback) ->
		@go callback
	
	where: (condition) ->
		@filter condition

module.exports = Query