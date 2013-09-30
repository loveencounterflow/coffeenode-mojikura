
############################################################################################################
njs_os                    = require 'os'
njs_fs                    = require 'fs'
njs_path                  = require 'path'
#...........................................................................................................
TEXT                      = require 'coffeenode-text'
SOLR                      = require 'coffeenode-solr'
TYPES                     = require 'coffeenode-types'
TRM                       = require 'coffeenode-trm'
CHR                       = require 'coffeenode-chr'
MOJIKURA                  = require '..'
log                       = TRM.log.bind TRM
rpr                       = TRM.rpr.bind TRM
echo                      = TRM.echo.bind TRM
#...........................................................................................................
suspend                   = require 'coffeenode-suspend'
step                      = suspend.step
collect                   = suspend.collect
immediately               = setImmediate
eventually                = process.nextTick



#-----------------------------------------------------------------------------------------------------------
MOJIKURA.query_from_matcher = ( me, matcher ) ->
  R = []
  switch type = TYPES.type_of matcher
    when 'text'
      return """sv:#{@quote matcher}"""
    when 'pod'
      for name, value of matcher
        null
  throw new Error "expected a text or a pod for a matcher, got a #{type}"

#-----------------------------------------------------------------------------------------------------------
MOJIKURA.search = ( me, matcher, options, handler ) ->
  unless handler?
    handler = options
    options = null
  #.........................................................................................................
  query = @query_from_matcher me, matcher
  #.........................................................................................................
  SOLR.search me, query, options, ( error, response ) =>
    return handler error if error?
    #.......................................................................................................
    results       = response[ 'results' ]
    #.......................................................................................................
    handler null, response
  #.........................................................................................................
  return null


############################################################################################################


#-----------------------------------------------------------------------------------------------------------
demo_search = ( glyph ) ->
  db = MOJIKURA.new_db()
  #.........................................................................................................
  options =
    'result-count':   500
    'sort':           'sk asc, pk asc, pi asc'
  #.........................................................................................................
  matcher =
    'sk':     'glyph'
    'sv':     glyph
  #.........................................................................................................
  # MOJIKURA.search db, matcher, options, ( error, entries ) ->
  MOJIKURA.search db, glyph, options, ( error, entries ) ->
    throw error if error?
    #.......................................................................................................
    log TRM.pink entries

#===========================================================================================================
demo_search '醪'












