

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
#...........................................................................................................
### see https://github.com/raszi/node-tmp ###
### TAINT
This module has the nasty property that it 'attracts' error stack traces — test code:

    tempfile = require 'tmp'
    eventually -> throw new Error 'oops'

and see how suddenly the first line of the stack trace points into the `tmp` module. The reason for this
is that they bind a temp file remover to the `uncaughtException` event. Not good.
###
tempfile                  = require 'tmp'
#...........................................................................................................
tempfile_options =
  # 'mode':       0o777
  'prefix':     'mojikura-data-batch'
  'postfix':    '.json'
  'tries':      5
  'keep':       yes

# db_route                  = '/Users/flow/cnd/node_modules/coffeenode-mojikura/data/jizura-mojikura.json'
# batch                     = []
# entry_count               = 0
# written_record_count      = 0
# #...........................................................................................................
# batch_size                = 1000
# report_size               = 250000
# max_entry_count           = 70
# max_entry_count           = Infinity
# update_method             = 'write-file'
# update_method             = 'post-batches'



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
  ### ???

    RangeError: Maximum call stack size exceeded
        at Object.save_nodes (/Users/flow/cnd/node_modules/coffeenode-mojikura/src/POSTER.coffee:104:16)
        at Object.save_cached_nodes (/Users/flow/cnd/node_modules/coffeenode-mojikura/src/populate.coffee:125:19)
        at /Users/flow/cnd/node_modules/coffeenode-mojikura/src/populate.coffee:543:21
        at GeneratorFunctionPrototype.next (native)
        at /Users/flow/cnd/node_modules/coffeenode-suspend/lib/main.js:39:31
        at process._tickCallback (node.js:317:11)
  ###
  # batch.push.apply batch, nodes
  batch.push node for node in nodes
  db[ 'entry-count' ] += nodes.length
  #.........................................................................................................
  if batch.length >= db[ 'batch-size' ]
    log TRM.pink db[ 'entry-count' ]
    # MOJIKURA.CACHE.log_report db
    @post_pending db, handler
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
      k:      node[ 'k'  ]
      v:      node[ 'v'  ]
    for predicate_route, ids of node
      continue if predicate_route is '~isa'
      continue if predicate_route is 'id'
      continue if predicate_route is 'k'
      continue if predicate_route is 'v'
      entry[ predicate_route ] = { add: ids, }
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
@clear_output_file = ( db, handler ) ->
  throw new Error "method POSTER.clear_output_file is deprecated"
  # log TRM.blue "clearing output file: #{db_route} ..."
  # njs_fs.writeFileSync db_route, '[\n'
  # #.........................................................................................................
  # eventually =>
  #   log TRM.blue "cleared output file"
  #   handler null, true
  # #.........................................................................................................
  # return null

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
    log TRM.blue "... posted"
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
  #.........................................................................................................
  MOJIKURA.update db, entries, ( error ) =>
    # log TRM.steel '©8r4 POSTER.post_and_commit_batch (cb)'
    return handler error if error?
    log TRM.blue "posted #{entries.length} entries"
    db[ 'batch' ].length = 0
    handler null, null
  #.........................................................................................................
  return null





