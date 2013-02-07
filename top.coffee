#!/usr/bin/env coffee

_ = require 'underscore'
async = require 'async'
request = require 'request'
program = require 'commander'
Table = require 'cli-table'
fs = require 'fs'
fs.path = require 'path'
utils = require './utils'

GUARDIAN_API = 'http://content.guardianapis.com/search'
SHAREDCOUNT_API = 'http://api.sharedcount.com/'

cache = new utils.FileCache './cache'

data = 
    getShareCount: (article, callback, retry = 0) ->
        if retry > 3
            errorMessage = "Could not get share count for #{article.webUrl} after 3 tries."

            if program.verbose
                console.log errorMessage
            else
                process.stdout.write '/'
                article.shares = NaN

            return callback [new Error errorMessage], null

        req = 
            url: SHAREDCOUNT_API
            json: yes
            qs:
                url: article.webUrl

        request req, (error, response, shares) ->
            # if shares is a string rather than an object, then that's
            # usually an error message
            if error or (typeof shares is 'string')
                if program.verbose
                    console.log "Error fetching share count for #{article.webUrl}"
                else
                    process.stdout.write '-'

                return setTimeout (-> data.getShareCount article, callback, retry+1), 1000
            else
                if program.verbose
                    console.log "Fetched share count for #{article.webUrl}"
                else
                    process.stdout.write '.'

            article.shares = shares
            article.shares.total = (_.values shares).reduce (a, b) ->
                if typeof a isnt 'number'
                    a = (a?.total_count or 0)
                if typeof b isnt 'number'
                    b = (b?.total_count or 0)

                a + b

            callback null

    getArticles: (date, callback) ->
        query = 
            url: GUARDIAN_API
            json: yes
            qs:
                'from-date': date
                'to-date': date
                'page-size': 50
                'page': 1
                'format': 'json'

        pages = 0
        articles = []

        incomplete = -> not pages or query.qs.page <= pages
        fetch = (done) ->
            request query, (error, response, chunk) ->
                articles.push chunk.response.results...
                pages = chunk.response.pages

                if program.verbose
                    console.log "Fetching content list #{query.qs.page} of #{pages}."

                query.qs.page += 1
                done()

        async.whilst incomplete, fetch, (err) ->
            callback err, articles

    getArticlesWithShareCounts: (range, callback) ->
        if not range.list?
            throw new Error "Range should be a DateRange object."

        fetch = (date, done) ->
            file = "#{date}.json"
            cache.get file, (err, cachedData) ->
                if cachedData
                    done err, cachedData
                else
                    data.getArticles date, (contentErrors, articles) ->
                        async.forEachSeries articles, data.getShareCount, (shareCountErrors) ->
                            process.stdout.write '\n'
                            errors = (contentErrors or []).concat (shareCountErrors or [])
                            unless errors.length then errors = null

                            cache.put file, articles, ->
                                done errors, articles

        async.mapSeries range.list, fetch, (errors, articles) ->
            callback errors, _.flatten articles


slicePopular = (articles, n) ->
    filteredArticles = articles.filter (article) ->
        (article.shares isnt NaN) and (typeof article.shares isnt 'string')
    sortedArticles = _.sortBy filteredArticles, (article) -> article.shares.total
    sortedArticles.slice(-n).reverse()

program
    .version('0.0.1')
    .option('-d, --days <n>', 'How many days of content to analyze.', parseInt)
    .option('-r, --range <r>', 'A range of dates to analyze. Don\'t forget to quote.')
    .option('-n, --number <n>', 'Show the top n articles.', parseInt)
    .option('-v, --verbose', 'Enable verbose output.')
    .option('-h, --humanize', 'Present output as a table rather than raw CSV.')
    .option('-p, --print', 'Print output to stdout rather than writing it to a results file.')
    .option('-m, --more', 'Include more detail about share counts of individual services. (Only in CSV output.)')
    .parse(process.argv)

selectedDateRange = new utils.DateRange program.days or program.range or 1
mostPopularSlice = program.number or 10

data.getArticlesWithShareCounts selectedDateRange, (errors, articles) ->
    for error in errors or []
        process.stderr.write error.toString()

    mostPopular = slicePopular articles, mostPopularSlice

    ###
    # spot fetch errors 

    a = articles.filter (article) -> typeof article.shares is 'string'
    console.log a.map (article) -> article.webPublicationDate
    ###

    if program.humanize
        table = new Table()
        mostPopular.forEach (article) ->
            table.push [
                article.shares.total
                [article.webTitle, article.webUrl].join('\n')
                ]

        out = 'Most talked about content from '
        out += selectedDateRange.toString()
        out += '\n'
        out += table.toString()
        ext = 'txt'
    else
        out = ''
        mostPopular.forEach (article) ->
            out += [
                article.shares.total
                article.webUrl
                ].join(',')
            out += '\n'
        ext = 'csv'

    if program.print
        console.log out
    else
        dest = "./results/#{selectedDateRange}.#{ext}".replace(/\s/g, '-')
        unless fs.existsSync './results'
            fs.mkdirSync './results'

        fs.writeFileSync dest, out, 'utf8'