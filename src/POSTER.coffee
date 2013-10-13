

############################################################################################################
njs_fs                    = require 'fs'
# njs_os                    = require 'os'
# njs_path                  = require 'path'
#...........................................................................................................
# TEXT                      = require 'coffeenode-text'
# TYPES                     = require 'coffeenode-types'
# CHR                       = require 'coffeenode-chr'
#...........................................................................................................
TRM                       = require 'coffeenode-trm'
log                       = TRM.log.bind TRM
rpr                       = TRM.rpr.bind TRM
echo                      = TRM.echo.bind TRM
#...........................................................................................................
# SOLR                      = require 'coffeenode-solr'
MOJIKURA                  = require '..'
#...........................................................................................................
suspend                   = require 'coffeenode-suspend'
# step                      = suspend.step
# collect                   = suspend.collect
# immediately               = setImmediate
eventually                = process.nextTick
#...........................................................................................................
### see https://github.com/raszi/node-tmp ###
### TAINT
This module has the nasty property that it 'attracts' error stack traces — test code:

    tempfile = require 'tmp'
    eventually -> throw new Error 'oops'

and see how suddenly the first line of the stack trace points into the `tmp` module. The reason for this
is that they bind a temp file remover to the `uncaughtException` event. Not good. ###
tempfile                  = require 'tmp'
#...........................................................................................................
tempfile_options =
  # 'mode':       0o777
  'prefix':     'mojikura-data-batch'
  'postfix':    '.json'
  'tries':      5
  'keep':       yes


#===========================================================================================================
# OBJECT CREATION
#-----------------------------------------------------------------------------------------------------------
@get_entry = ( db, t, k, v ) ->
  cache     = db[ 'cache' ]
  target    = cache[ k ]?= {}
  R         = target[ v ]
  return R if R?
  return target[ v ] = MOJIKURA.new_entry db, t, k, v

#-----------------------------------------------------------------------------------------------------------
@cache_entry = ( db, entry ) ->
  cache       = db[ 'cache' ]
  k           = entry[ 'k' ]
  v           = entry[ 'v' ]
  target      = cache[ k ]?= {}
  target[ v ] = entry
  return entry

#-----------------------------------------------------------------------------------------------------------
@_clear_cache = ( db ) ->
  cache     = db[ 'cache' ]
  for k of cache
    delete cache[ k ]
  return null

#-----------------------------------------------------------------------------------------------------------
@push_facet = ( P... ) -> return MOJIKURA.push_facet P...
@set_facet  = ( P... ) -> return MOJIKURA.set_facet  P...

#-----------------------------------------------------------------------------------------------------------
@save_cache = ( db, handler ) ->
  nodes = @_entries_from_cache db
  @_clear_cache db
  if nodes.length is 0
    log TRM.blue "(nothing to post)"
    return
  return @save_nodes db, nodes, handler

#-----------------------------------------------------------------------------------------------------------
@_entries_from_cache = ( db ) ->
  cache     = db[ 'cache' ]
  R         = []
  for k, target of cache
    for v, node of target
      R.push node
  return R


#===========================================================================================================
# TOP LEVEL
#-----------------------------------------------------------------------------------------------------------
@initialize = ( db, handler ) ->
  db[ 'batch' ] = []
  log TRM.blue "DB update method: #{rpr db[ 'update-method' ]}"
  @clear db, handler
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@finalize = ( db, handler ) ->
  # log '©4r1', TRM.yellow db
  #.........................................................................................................
  @post_pending db, ( error ) =>
    return handler error if error?
    #.......................................................................................................
    if db[ 'update-method' ] is 'write-file' and not db[ 'post-files' ]
      log()
      log TRM.blue "data has been written to the following files:"
      for output_route in db[ '%data-file-routes' ]
        log TRM.blue "  #{output_route}"
      log()
      return handler null
    #.......................................................................................................
    # if db[ 'update-method' ] isnt 'write-file'
    @commit db, handler
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@post_pending = ( db, handler ) ->
  #.........................................................................................................
  if db[ 'update-method' ] is 'write-file' then @write_and_post_file    db, handler
  else                                          @post_and_commit_batch  db, handler
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@save_nodes = ( db, nodes, handler ) ->
  batch = db[ 'batch' ]
  batch.push node for node in nodes
  db[ 'entry-count' ] += nodes.length
  #.........................................................................................................
  if true # batch.length >= db[ 'batch-size' ]
    log TRM.pink db[ 'entry-count' ]
    # MOJIKURA.CACHE.log_report db
    @post_pending db, ( error ) =>
      return handler error if error?
      @commit db, handler
  #.........................................................................................................
  else
    eventually => handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@clear = ( db, handler ) ->
  @conditionally_clear_db db, handler
  return null

#-----------------------------------------------------------------------------------------------------------
@commit = ( db, handler ) ->
  log TRM.blue "committing data..."
  MOJIKURA.commit db, ( error ) =>
    return handler error if error?
    log TRM.blue "... committed."
    handler null

#-----------------------------------------------------------------------------------------------------------
@_entries_from_batch = ( db ) ->
  R = []
  #.........................................................................................................
  for node, idx in db[ 'batch' ]
    entry =
      id:     node[ 'id' ]
      # k:      node[ 'k'  ]
      # v:      node[ 'v'  ]
    for key, value of node
      continue if key is '~isa'
      continue if key is 'id'
      # continue if key is 'k'
      # continue if key is 'v'
      if ( key.match /^(s|k|v)/ )
        entry[ key ] = { set: value, }
      else
        entry[ key ] = { add: value, }
    R.push entry
  #.........................................................................................................
  return R


#===========================================================================================================
# FILE WRITING
#-----------------------------------------------------------------------------------------------------------
@_new_tempfile = ( handler ) ->
  ### Calls back with route of newly created file. ###
  tempfile.file options, ( error, route, file_descriptor ) ->
    return handler error if error?
    log TRM.grey "created temporary file at #{route}"
    handler null, route

#-----------------------------------------------------------------------------------------------------------
@write_and_post_file = ( db, handler ) ->
  tempfile.file tempfile_options, ( error, output_route, file_descriptor ) =>
    return handler error if error?
    #.......................................................................................................
    log TRM.pink "©3e2 created output file at #{output_route}"
    ( db[ '%data-file-routes' ]?= [] ).push output_route
    #.......................................................................................................
    njs_fs.appendFileSync output_route, '[\n'
    entries   = @_entries_from_batch db
    last_idx  = entries.length - 1
    #.......................................................................................................
    for entry, idx in entries
      line = JSON.stringify entry
      njs_fs.appendFileSync output_route, if idx < last_idx then line.concat ',\n' else line
    #.......................................................................................................
    njs_fs.appendFileSync output_route, '\n]\n'
    db[ 'batch' ].length = 0
    #.......................................................................................................
    if db[ 'post-files' ]
      @post_output_file db, output_route, handler
    else
      eventually => handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@post_output_file = ( db, route, handler ) ->
  log TRM.blue "posting file #{route} to DB..."
  #.........................................................................................................
  MOJIKURA.update_from_file db, route, ( error ) =>
    return handler error if error?
    log TRM.blue "... done"
    handler null, null
  #.........................................................................................................
  return null


#===========================================================================================================
# BATCH POSTING
#-----------------------------------------------------------------------------------------------------------
@conditionally_clear_db = ( db, handler ) ->
  if db[ 'clear-db' ]
    log TRM.blue "clearing DB..."
    MOJIKURA.clear db, ( error, response ) ->
      return handler error if error?
      log TRM.blue "DB has been cleared"
      handler null, true
  else
    log TRM.blue "DB has", ( TRM.red "not" ), "been cleared"
    eventually => handler null, false
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@post_and_commit_batch = ( db, handler ) ->
  entries = @_entries_from_batch db
  log TRM.blue "posting #{entries.length} entries..."
  #.........................................................................................................
  MOJIKURA.update db, entries, ( error ) =>
    # log TRM.steel '©8r4 POSTER.post_and_commit_batch (cb)'
    return handler error if error?
    log TRM.blue "... done"
    db[ 'batch' ].length = 0
    handler null, null
  #.........................................................................................................
  return null





