


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
log                       = TRM.log.bind TRM
rpr                       = TRM.rpr.bind TRM
echo                      = TRM.echo.bind TRM
#...........................................................................................................
suspend                   = require 'coffeenode-suspend'
step                      = suspend.step
collect                   = suspend.collect
immediately               = setImmediate
#...........................................................................................................
# db_route                  = njs_path.join __dirname, 'data/mojikura2-study.mjkrdb'



#===========================================================================================================
# DB CREATION
#-----------------------------------------------------------------------------------------------------------
@new_db = ( P... ) ->
  return SOLR.new_db P...


#===========================================================================================================
# ENTRY CREATION
#-----------------------------------------------------------------------------------------------------------
@new_node = ( db, key, value ) ->
  if ( TYPES.type_of value ) is 'text'
    format      = null
    value_text  = value
  else
    format      = 'json'
    value_text  = JSON.stringify value
  #.........................................................................................................
  id = key.concat '/', value_text
  #.........................................................................................................
  R =
    id:         id
    isa:        'node'
    key:        key
    format:     format
    value:      value_text
  #.........................................................................................................
  @_register db, R
  return R

#-----------------------------------------------------------------------------------------------------------
@new_edge = ( db, from_id, key, to_id, idx ) ->
  # from_entry  = @get db, from_id
  # to_entry    = @get db, to_id
  id          = from_id.concat ';', key, '#', idx, ';', to_id
  #.........................................................................................................
  R =
    id:         id
    idx:        idx
    isa:        'edge'
    key:        key
    from:       from_id
    to:         to_id
  #.........................................................................................................
  @_register db, R
  return R


#===========================================================================================================
# POPULATE DB
#-----------------------------------------------------------------------------------------------------------
@populate = ( db, entries, handler ) ->
  for entry in entries
    @_cast_to_db  db, entry
    @_register    db, entry
  SOLR.update db, entries, ( error, response ) ->
    return handler error, response if handler?
    @_cast_from_db db, entry for entry in entries
    log TRM.blue """DB populated:
      #{rpr response}"""


#===========================================================================================================
# CACHE
#-----------------------------------------------------------------------------------------------------------
### Cache is maintained on module level, as this library is not intented to work with more than a single
database collection—which means that IDs uniquely identify entries across our problem domain. ###
@_cache                   = {}
@_cache_node_entry_count  = 0
@_cache_edge_entry_count  = 0
@_cache_entry_count       = 0
@_cache_hit_count         = 0
@_cache_miss_count        = 0

#-----------------------------------------------------------------------------------------------------------
@_register = ( db, entry ) ->
  ### TAINT: should check for object identity in case ID is known ###
  id = entry[ 'id' ]
  #.........................................................................................................
  if ( cached_entry = @_cache[ id ] )?
    throw new Error "another entry with ID #{rpr id} already exists" if entry isnt cached_entry
  #.........................................................................................................
  else
    @_cache[ id ]         = entry
    @_cache_entry_count  += 1
    if entry[ 'isa' ] is 'node' then @_cache_node_entry_count += 1 else @_cache_edge_entry_count += 1
  #.........................................................................................................
  return entry

#-----------------------------------------------------------------------------------------------------------
@get = ( db, id, fallback, handler ) ->
  ### Given an `id`, call the `handler` with the associated DB entry, either from the cache or by calling
  `SOLR.get`. The method always works asynchronously, even when entries are retrieved from cache. ###
  unless handler?
    handler   = fallback
    ### TAINT: shouldn't use `undefined` ###
    fallback  = undefined
  #.........................................................................................................
  Z       = @_cache[ id ]
  misfit  = {}
  #.........................................................................................................
  if Z?
    @_cache_hit_count += 1
    return ( immediately -> handler null, Z )
  #=========================================================================================================
  SOLR.get db, id, misfit, ( error, Z ) =>
    @_cache_miss_count += 1
    #.......................................................................................................
    return handler error if error?
    #.......................................................................................................
    if Z is misfit
      return if fallback is undefined then handler error else handler null, fallback
    #.......................................................................................................
    handler null, @_register db, @_cast_from_db db, Z
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@search = ( db, P..., handler ) ->
  #=========================================================================================================
  SOLR.search db, P..., ( error, response ) =>
    return handler error if error?
    #.......................................................................................................
    results = response[ 'results' ]
    #.......................................................................................................
    for entry, idx in results
      cached_entry = @_cache[ entry[ 'id' ] ]
      if cached_entry?
        results[ idx ] = cached_entry
      else
        @_register db, @_cast_from_db db, entry
    #.......................................................................................................
    handler null, response
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@log_cache_report = ( db ) ->
  log()
  log TRM.grey    '   ---------------------'
  log TRM.orange  '   MojiKura Cache Report'
  log TRM.grey    '   ---------------------'
  log()
  log TRM.blue    "   #{@_cache_node_entry_count} nodes"
  log TRM.blue    " + #{@_cache_edge_entry_count} edges"
  log TRM.grey    '   ---------------------'
  log TRM.blue    " = #{@_cache_entry_count} entries"
  log TRM.grey    '   ====================='
  log()
  log TRM.green   "   #{@_cache_hit_count} cache hits"
  log TRM.red     " + #{@_cache_miss_count} cache misses"
  log TRM.grey    '   ---------------------'
  log TRM.orange  " = #{@_cache_hit_count + @_cache_miss_count} cache accesses"
  log TRM.grey    '   ====================='
  log()


#===========================================================================================================
# ENTRY CASTING
#-----------------------------------------------------------------------------------------------------------
@_cast_from_db = ( db, entry ) ->
  return @_cast db, entry, 'parse'

#-----------------------------------------------------------------------------------------------------------
@_cast_to_db = ( db, entry ) ->
  return @_cast db, entry, 'stringify'

#-----------------------------------------------------------------------------------------------------------
@_cast = ( db, entry, method_name ) ->
  return entry unless ( format = entry[ 'format' ] )?
  #.........................................................................................................
  switch format
    when 'json' then entry[ 'value' ] = JSON[ method_name ] entry[ 'value' ]
    when 'text' then null
    else throw new Error "unknown casting format #{rpr format}"
  #.........................................................................................................
  return entry


