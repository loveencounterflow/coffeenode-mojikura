

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
@add_entry = ( db, entry, handler ) ->
  # log TRM.orange '©5w2 POSTER.add_entry'
  batch = db[ 'batch' ]
  batch.push entry
  #.........................................................................................................
  db[ 'entry-count' ] += 1
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
    #.........................................................................................................
    log TRM.pink "©3e2 created output file at #{output_route}"
    ( db[ '%data-file-routes' ]?= [] ).push output_route
    batch = db[ 'batch' ]
    #.........................................................................................................
    njs_fs.appendFileSync output_route, '[\n'
    lines = ( JSON.stringify entry for entry in batch )
    njs_fs.appendFileSync output_route, lines.join ',\n'
    njs_fs.appendFileSync output_route, '\n]\n'
    batch.length = 0
    #.........................................................................................................
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
    log TRM.blue "DB has *not* been cleared"
    eventually => handler null, false
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@post_and_commit_batch = ( db, handler ) ->
  batch = db[ 'batch' ]
  # log TRM.steel '©8r4', batch
  #.........................................................................................................
  MOJIKURA._update db, batch, ( error ) =>
    # log TRM.steel '©8r4 POSTER.post_and_commit_batch (cb)'
    return handler error if error?
    log TRM.blue "posted #{batch.length} entries"
    batch.length = 0
    handler null, null
  #.........................................................................................................
  return null





