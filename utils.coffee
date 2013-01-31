fs = require 'fs'
fs.path = require 'path'
moment = require 'moment'

class exports.DateRange
    constructor: (n) ->
        @from = moment().subtract('days', n).format('YYYY-MM-DD')
        @to = moment().subtract('days', 1).format('YYYY-MM-DD')
        @list = (moment().subtract('days', i).format('YYYY-MM-DD') for i in [1..n]).reverse()

    toString: ->
        if @from is @to
            @from
        else
            "#{@from}-to-#{@to}"

# creating and cleaning the cache are synchronous because these are generally init steps
class exports.FileCache
    constructor: (@basepath) ->
        unless fs.existsSync @basepath
            fs.mkdirSync @basepath

    hash: (uri) -> uri

    has: (uri, callback) ->
        fs.path.exists (@path uri), callback

    path: (uri) ->
        fs.path.join @basepath, @hash uri

    get: (uri, callback) ->
        @has uri, (exists) =>
            if exists
                path = (@path uri)
                fs.readFile (@path uri), 'utf8', (err, data) ->
                    if path.slice(-5) is '.json' and data
                        data = JSON.parse data
                    callback err, data
            else
                callback null, null

    put: (uri, content, callback) ->
        if uri.slice(-5) is '.json'
            content = JSON.stringify content
        fs.writeFile (@path uri), content, 'utf8', callback

    clean: ->
        fs.rmdirSync @basepath