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

            return callback [new Error errorMessage], null

        req = 
            url: SHAREDCOUNT_API
            json: yes
            qs:
                url: article.webUrl

        request req, (error, response, shares) ->
            if error
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

            article.shareCount = (_.values shares).reduce (a, b) ->
                if b instanceof Number
                    a + b
                else if b is null
                    a
                else
                    a + (b?.total_count or 0)

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
    sortedArticles = _.sortBy articles, (article) -> article.shareCount
    sortedArticles.slice(-n).reverse()

program
    .version('0.0.1')
    .option('-d, --days <n>', 'How many days of content to analyze.', parseInt)
    .option('-n, --number <n>', 'Show the top n articles.', parseInt)
    .option('-v, --verbose', 'Enable verbose output.')
    .parse(process.argv)

selectedDateRange = new utils.DateRange program.days or 1
mostPopularSlice = program.number or 10

data.getArticlesWithShareCounts selectedDateRange, (errors, articles) ->
    for error in errors or []
        process.stderr.write error.toString()

    mostPopular = slicePopular articles, mostPopularSlice

    table = new Table()
    mostPopular.forEach (article) ->
        table.push [
            article.shareCount
            [article.webTitle, article.webUrl].join('\n')
            ]

    dest = "./results/#{selectedDateRange}.txt"

    unless fs.existsSync './results'
        fs.mkdirSync './results'

    fs.writeFileSync dest, table.toString(), 'utf8'