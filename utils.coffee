fs = require 'fs'
fs.path = require 'path'

DAY = 60 * 60 * 24 * 1000

class exports.DateRange
    constructor: (n) ->
        if typeof n is 'string'
            [from, to] = (n.split ' ')
            @to = new Date to
            @from = new Date from
            n = (@to - @from) / DAY
        else
            n = n-1
            @to = new Date(new Date() - DAY)
            @from = new Date(@to - n*DAY)

        @list = ((@human @to - DAY*i) for i in [0..n]).reverse()

    human: (date) ->
        if typeof date is 'number'
            date = new Date date
        else if typeof date is 'string'
            date = @[date]

        date.toISOString()[..9]

    toString: ->
        if @from is @to
            @human 'from'
        else
            "#{@human('from')} to #{@human('to')}"

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