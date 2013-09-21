

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
  @post_pending db, ( error ) ->
    return handler error if error?
    if db[ 'update-method' ] is 'write-file' and not db[ 'post-files' ]
      throw new Error 'POSTER.finalize not yet implemented'
      ### log all the file routes we've been writing to ###

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
    MOJIKURA.CACHE.log_report db
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
  tempfile.file options, ( error, route, file_descriptor ) =>
    return handler error if error?
    log TRM.pink "©3e2 created output file at #{route}"
    ( db[ '%data-file-routes' ]?= [] ).push data_file_route


    batch = db[ 'batch' ]
    #.........................................................................................................
    # log TRM.cyan batch
    if batch.length is 0
      njs_fs.appendFileSync db_route, '\n' #]\n'
    #.........................................................................................................
    else
      lines = []
      for entry in batch
        continue if entry[ '%is-clean' ]
        value = entry[ 'value' ]
        MOJIKURA._cast_to_db db, entry
        lines.push JSON.stringify entry
        MOJIKURA._cast_from_db db, entry, value
        MOJIKURA.CACHE._clean db, entry
      if db[ 'file-entry-count' ] is 0
        njs_fs.appendFileSync db_route, lines.join ',\n'
      else
        njs_fs.appendFileSync db_route, ',\n'.concat ( lines.join ',\n' ) # , '\n]\n'
    #.........................................................................................................
    db[ 'file-entry-count' ] += lines.length
    batch.length = 0
    eventually => handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@finalize_output_file = ( db, handler ) ->
  throw new Error "finalize_output_file is deprecated"
  # batch = db[ 'batch' ]
  # #.........................................................................................................
  # @write_and_post_file db, ( error ) =>
  #   return handler error if error?
  #   njs_fs.appendFileSync db_route, '\n]\n'
  #   log TRM.blue "#{db[ 'file-entry-count' ]} entries written to #{db_route}"
  #   #.......................................................................................................
  #   @post_output_file db, ( error ) =>
  #     return handler error if error?
  #     #.....................................................................................................
  #     @commit db, ( error ) =>
  #       return handler error if error?
  #       handler null, null
  # #.........................................................................................................
  # return null

#-----------------------------------------------------------------------------------------------------------
@post_output_file = ( db, handler ) ->
  log TRM.blue "posting file #{db_route} to DB..."
  #.........................................................................................................
  MOJIKURA.update_from_file db, db_route, ( error ) =>
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

#-----------------------------------------------------------------------------------------------------------
@finalize_batch_post = ( db, handler ) ->
  throw new Error "finalize_output_file is deprecated"
  # batch = db[ 'batch' ]
  # # log '©2w9', TRM.pink batch
  # #.........................................................................................................
  # if batch.length is 0
  #   @commit db, handler
  # else
  #   @post_and_commit_batch db, ( error ) =>
  #     return handler error if error?
  #     @commit db, handler
  # #.........................................................................................................
  # return null



