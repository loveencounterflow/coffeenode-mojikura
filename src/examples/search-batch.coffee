


############################################################################################################
TEXT                      = require 'coffeenode-text'
TYPES                     = require 'coffeenode-types'
TRM                       = require 'coffeenode-trm'
CHR                       = require 'coffeenode-chr'
log                       = TRM.log.bind TRM
rpr                       = TRM.rpr.bind TRM
echo                      = TRM.echo.bind TRM
#...........................................................................................................
SOLR                      = require 'coffeenode-solr'
MOJIKURA                  = require '../..'
QUERY                     = MOJIKURA.QUERY
#...........................................................................................................
suspend                   = require 'coffeenode-suspend'
step                      = suspend.step
# collect                   = suspend.collect
# immediately               = setImmediate
# eventually                = process.nextTick


#-----------------------------------------------------------------------------------------------------------
f = ->
  #.........................................................................................................
  step ( resume ) ->*
    db      = MOJIKURA.new_db()
    query   = [ { k: 'glyph', }, { v: QUERY.wildcard '*', }, ]
    options =
      'result-count':     5000
    #.......................................................................................................
    while ( batch = yield MOJIKURA.batch_search db, query, options, resume )
      # log()
      log TRM.green options, TRM.pink batch.length
      # if options
      # for entry, idx in batch
      #   log TRM.rainbow entry
      #   break if idx > 3

f()

