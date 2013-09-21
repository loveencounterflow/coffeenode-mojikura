


############################################################################################################
njs_os                    = require 'os'
njs_fs                    = require 'fs'
njs_path                  = require 'path'
njs_crypto                = require 'crypto'
#...........................................................................................................
TEXT                      = require 'coffeenode-text'
SOLR                      = require 'coffeenode-solr'
POSTER                    = require './POSTER'
TYPES                     = require 'coffeenode-types'
TRM                       = require 'coffeenode-trm'
CHR                       = require 'coffeenode-chr'
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
@CACHE                    = SOLR.CACHE
#...........................................................................................................
@db_defaults =
  'batch-size':           1000
  'report-size':          250000
  'max-entry-count':      Infinity
  'update-method':        'write-file'
  'update-method':        'post-batches'
  # 'db-route':             njs_path.join __dirname, '../data', 'jizura-mojikura.json'
  'batch':                []
  'entry-count':          0
  'file-entry-count':     0
  'clear-db':             yes


#===========================================================================================================
# DB CREATION
#-----------------------------------------------------------------------------------------------------------
@new_db = ( P... ) ->
  R = SOLR.new_db P...
  #.........................................................................................................
  for name, value of @db_defaults
    R[ name ] = value unless R[ name ]?
  #.........................................................................................................
  return R


#===========================================================================================================
# ENTRY DELETION
#-----------------------------------------------------------------------------------------------------------
@clear = ( db, handler ) ->
  return SOLR.clear db, handler


#===========================================================================================================
# ENTRY CREATION
#-----------------------------------------------------------------------------------------------------------
@new_node = ( db, key, value, handler ) ->
  # log TRM.cyan '©7z3 MOJIKURA.new_node'
  #.........................................................................................................
  Z =
    id:         @get_node_id db, key, value
    isa:        'node'
    key:        key
    value:      value
  #.........................................................................................................
  Z = @CACHE.wrap_and_register db, Z #, ( error ) ->
    # log TRM.cyan '©7z3 MOJIKURA.new_node callback'
    # return handler error if error?
  # log TRM.cyan '©7z3 MOJIKURA.new_node (b)'
  eventually -> handler null, Z
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@new_edge = ( db, from_id, key, to_id, idx, handler ) ->
  ### TAINT: should ckeck that both nodes exist ###
  # from_entry  = @get db, from_id
  # to_entry    = @get db, to_id
  #.........................................................................................................
  Z =
    id:         @get_edge_id db, from_id, key, to_id, idx
    idx:        idx
    isa:        'edge'
    key:        key
    from:       from_id
    to:         to_id
  #.........................................................................................................
  Z = @CACHE.wrap_and_register db, Z #, ( error ) ->
    # return handler error if error?
    # handler null, Z
  eventually -> handler null, Z
  #.........................................................................................................
  return null

# #-----------------------------------------------------------------------------------------------------------
# @fetch_cached_node = ( db, key, value ) ->
#   ### Given a `key` and a `value`, return either a node from the cache, or a new node (that is cached before
#   returning). The database will not be queried, so it may be advisable to run `MOJIKURA.get_all` prior to
#   using this method, depending on circumstances. ###
#   id  = @get_node_id db, 'glyph', glyph
#   SOLR.CACHE.retrieve db

#   R   = db[ '%cache' ][ 'value_by_id' ][ id ]
#   #.....................................................................................................
#   if R is null
#     R = MOJIKURA.new_node db, 'glyph', glyph
#     # log TRM.red '©7z8', R[ 'id' ]
#     @_add_entry db, R
#   #.....................................................................................................
#   return R

#-----------------------------------------------------------------------------------------------------------
@get_node_id = ( db, key, value ) ->
  ### TAINT: should escape strings ###
  return @get_hash db, key.concat '/', JSON.stringify value

#-----------------------------------------------------------------------------------------------------------
@get_edge_id = ( db, from_id, key, to_id, idx ) ->
  ### TAINT: should escape strings ###
  return @get_hash db, from_id.concat ';', key, '#', idx, ';', to_id


#===========================================================================================================
# CRYPTO-HASHED IDS
#-----------------------------------------------------------------------------------------------------------
@get_hash = ( db, text ) ->
  ### TAINT: hash characteristics should go to options ###
  ### TAINT: should use xxhash where available ###
  # hash_name = 'rsa-sha512'
  # hash_name = 'sha1'
  # hash_name = 'md5'
  hash_name = 'sha256'
  hash_size = 12
  return ( ( ( njs_crypto.createHash hash_name ).update text, 'utf-8' ).digest 'hex' ).substr 0, hash_size


#===========================================================================================================
# POPULATE DB
#-----------------------------------------------------------------------------------------------------------
@update = ( db, entries, handler ) ->
  entries = [ entries ] unless TYPES.isa_list entries
  #.........................................................................................................
  for entry, idx in entries
    entries[ idx ] = @CACHE.wrap_and_register db, entry
  @_update db, entries, handler
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@_update = ( db, entries, handler ) ->
  #.........................................................................................................
  for idx in [ entries.length - 1 .. 0 ] by -1
    entry = entries[ idx ]
    ### JavaScript's way of saying `list.remove idx` ###
    if entry[ '%is-clean' ] then  entries.splice idx, 1
    else                          @_cast_to_db db, entry
  ### KLUDGE: prevent this same iteration from being repeated in SOLR.update: ###
  entries[ '%dont-modify' ] = yes
  #.........................................................................................................
  SOLR.update db, entries, ( error, response ) =>
    throw error if error?
    @_cast_from_db db, entry for entry in entries
    # log TRM.blue """DB update:
    #   #{rpr response}"""
    return handler null, response if handler?
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@update_from_file = ( me, route, content_type, handler ) ->
  ### OBS bypasses cache ###
  return SOLR.update_from_file me, route, content_type, handler

#-----------------------------------------------------------------------------------------------------------
@commit = ( db, handler ) ->
  SOLR.commit db, handler
  #.........................................................................................................
  return null


#===========================================================================================================
# GET BY ID
#-----------------------------------------------------------------------------------------------------------
@get = ( db, id, fallback, handler ) ->
  ### Given an `id`, call the `handler` with the associated DB entry, either from the cache or by calling
  `SOLR.get`. The method always works asynchronously, even when entries are retrieved from cache. ###
  unless handler?
    handler   = fallback
    ### TAINT: shouldn't use `undefined` ###
    fallback  = undefined
  #=========================================================================================================
  SOLR.get db, id, fallback, ( error, Z ) =>
    return handler error if error?
    @_cast_from_db db, Z unless Z is fallback
    handler null, Z
  #=========================================================================================================
  return null

#-----------------------------------------------------------------------------------------------------------
@search = ( db, P..., handler ) ->
  #=========================================================================================================
  SOLR.search db, P..., ( error, response ) =>
    return handler error if error?
    #.......................................................................................................
    results       = response[ 'results' ]
    @_cast_from_db db, entry for entry in results
    # #.......................................................................................................
    # if db[ 'use-cache' ] ? yes
    #   cache         = db[ '%cache' ]
    #   value_by_id   = cache[ 'value-by-id' ]
    #   #.....................................................................................................
    #   for entry, idx in results
    #     cached_entry = value_by_id[ entry[ 'id' ] ]
    #     if cached_entry? then results[ idx ] = cached_entry
    #     else                  @_cast_from_db db, entry
    # #.......................................................................................................
    # else
    #.......................................................................................................
    handler null, response
  #.........................................................................................................
  return null


#===========================================================================================================
# ENTRY CASTING
#-----------------------------------------------------------------------------------------------------------
@_cast_from_db = ( db, entry, value ) ->
  return entry unless ( format = entry[ 'format' ] )?
  throw new Error "unknown casting format #{rpr format}" unless format is 'json'
  delete entry[ 'format' ]
  entry[ 'value' ] = value ? JSON.parse entry[ 'value' ]
  return entry
  # #.........................................................................................................
  # return entry if entry[ 'isa' ] isnt 'node'
  # return entry if entry[ 'is-live' ]
  # if format = entry[ 'format' ] is 'json'
  #   entry[ 'value' ] = JSON.parse entry[ 'value' ]
  # else
  #   decode = db[ 'formats' ]?[ format ]?[ 'decode' ]
  #   throw new Error "unregistered format #{rpr format}" unless decode?
  #   entry[ 'value' ] = decode entry[ 'value' ]
  # entry[ 'is-live' ] = yes
  # return entry

#-----------------------------------------------------------------------------------------------------------
@_cast_to_db = ( db, entry ) ->
  # log '©5p1', TRM.pink entry
  return entry if entry[ 'isa' ] isnt 'node'
  return entry if ( format = entry[ 'format' ] ) is 'json'
  return entry if ( TYPES.type_of entry[ 'value' ] ) is 'text'
  throw new Error "unknown casting format #{rpr format}" if format?
  entry[ 'format' ] = 'json'
  entry[ 'value'  ] = JSON.stringify entry[ 'value' ]
  return entry
  # #.........................................................................................................
  # return entry if entry[ 'isa' ] isnt 'node'
  # delete entry[ 'is-live' ]
  # return entry

#===========================================================================================================
# QUERY TERM ESCAPING AND QUOTING
#-----------------------------------------------------------------------------------------------------------
@escape = ( P... ) -> return SOLR.escape  P...
@quote  = ( P... ) -> return SOLR.quote   P...






