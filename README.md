## About

Guardian Most Talked About grabs last day's or last week's Guardian Content, figures out how many shares each article got on various social networks like Facebook and Twitter (see http://sharedcount.com/documentation.php for a full list).

The application only works on Guardian content, but could be useful as the basis 
for a similar app for any website. Just swap out the Guardian Content API for 
whatever your source for article lists is.

## Installation

    git clone https://github.com/stdbrouw/guardian-most-talked-about.git
    npm install coffee-script -g
    cd guardian-most-talked-about
    npm install .

## Usage

Guardian Most Talked About is a command-line app. Figure out all the different flags
by typing: 

    ./top.coffee --help

Some example commands: 

    # Return a top 20 for the last seven days, with verbose (debugging) output
    ./top.coffee --days 7 --number 20 --verbose

    # Return a top 10 of last day's content
    ./top-coffee

Results will be in the `./results` directory.

Because the application fetches the sharecounts for each individual article published in the daterange you specified, and because it fetches these sharecounts sequentially (so as not to hammer the APIs it uses) expect it to take at least a couple of minutes per day of content.

It is currently not possible to specify an arbitrary date range: you can specify from when to
start using `--days` but the end of the range will always be yesterday.

## Troubleshooting

First off, enable `--verbose` operation. It'll show more clearly where things go wrong.
Secondly, take a look in the `./cache` directory. The app caches share counts because 
they take so long to fetch, but if something goes wrong, the wrong results may stick 
around in the cache too. You can take a look at the cached JSON, or you can simply delete
the cache and try again.

## License

Guardian Most Talked About comes with an MIT license.

## Thanks

The Guardian Frontend team for hosting me at Kings Place.
Knight-Mozilla OpenNews for supporting my work.
Yahel Carmon for the awesome sharedcount.com service.