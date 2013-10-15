


############################################################################################################
njs_os                    = require 'os'
njs_fs                    = require 'fs'
njs_path                  = require 'path'
njs_crypto                = require 'crypto'
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
### used to enable proxies; see https://github.com/tvcutsem/harmony-reflect ###
# require 'harmony-reflect'
#...........................................................................................................
suspend                   = require 'coffeenode-suspend'
# step                      = suspend.step
# collect                   = suspend.collect
immediately               = setImmediate
eventually                = process.nextTick
#...........................................................................................................
@SCHEMA                   = require './SCHEMA'
@QUERY                    = require './QUERY'
@POSTER                   = require './POSTER'
# @populate                 = require './populate'
#...........................................................................................................
@db_defaults =
  'batch-size':           1000
  'report-size':          250000
  'max-entry-count':      Infinity
  'update-method':        'write-file'
  'update-method':        'post-batches'
  # 'db-route':             njs_path.join __dirname, '../data', 'jizura-mojikura.json'
  'schema-route':         njs_path.join __dirname, '../db/schema.xml'
  'cache':                {}
  'entry-count':          0
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
  R[ '~isa'   ] = 'MOJIKURA/db'
  R[ 'schema' ]?= @SCHEMA.read R
  #.........................................................................................................
  return R


#===========================================================================================================
# REPRESENTATION
#-----------------------------------------------------------------------------------------------------------
@rpr = ( x ) ->
  switch type = TYPES.type_of x
    when 'MOJIKURA/entry' then return @rpr_of_entry x
    when 'MOJIKURA/db'    then return @rpr_of_db    x
  throw new Error "expected a MojiKura entry or DB, got a #{type}"

# #-----------------------------------------------------------------------------------------------------------
# @_escape_key = ( key ) ->
#   return key.replace /([:,])/g, '\\$1'

# #-----------------------------------------------------------------------------------------------------------
# @_unescape_key = ( key ) ->
#   return key.replace /(\\[:,])/g, '$1'

#-----------------------------------------------------------------------------------------------------------
@rpr_of_db = ( db ) ->
  throw new Error "not implemented"

#-----------------------------------------------------------------------------------------------------------
@rpr_of_entry = ( entry, with_id = no ) ->
  throw new Error "not implemented"


#===========================================================================================================
# ENTRY DELETION
#-----------------------------------------------------------------------------------------------------------
@clear = ( db, handler ) ->
  return SOLR.clear db, handler


#===========================================================================================================
# ENTRY CREATION
#-----------------------------------------------------------------------------------------------------------
@new_entry = ( me, t, k, v ) ->
  #.........................................................................................................
  R =
    '~isa':         'MOJIKURA/entry'
  #.........................................................................................................
  [ id
    t
    n   ]  = @_id_type_and_fieldname_from_facet me, t, k, v
  #.........................................................................................................
  R[ 'id' ]     = id
  R[ 'k'  ]     = k
  R[ 't'  ]     = t if t?
  R[ 'n'  ]     = n if n isnt 'v'
  R[  n   ]     = v
  #.........................................................................................................
  return R

#-----------------------------------------------------------------------------------------------------------
@_id_type_and_fieldname_from_facet = ( me, t, k, v ) ->
  #.........................................................................................................
  if ( not t? ) or t.length is 0
    t = null
    n = 'v'
    m = ''
  else
    n = 'v.'.concat t
    m = '('.concat t, ')'
  ### TAINT must escape value ###
  ### TAINT consider datatypes that are not JSON-serializable ###
  v_txt = if ( TYPES.type_of v ) is 'text' then v else JSON.stringify v
  id    = k.concat m, ':', v_txt
  #.........................................................................................................
  return [ id, t, n, ]


#===========================================================================================================
# ENTRY MANIPULATION
#-----------------------------------------------------------------------------------------------------------
@add_facet = ( me, entry, key, value ) ->
  if ( schema = me[ 'schema' ] )?
    field_info = schema[ key ]
    throw new Error "DB has schema but no entry for field #{rpr key}" unless field_info
    throw new Error "unable to push to single-value field #{rpr key}" unless field_info[ 'is-multi' ]
  #.........................................................................................................
  ( entry[ key ]?= [] ).push value
  return null

#-----------------------------------------------------------------------------------------------------------
@set_facet = ( me, entry, key, value ) ->
  if ( schema = me[ 'schema' ] )?
    field_info = schema[ key ]
    throw new Error "DB has schema but no entry for field #{rpr key}"   unless field_info
    throw new Error "must use `add_facet` with multi-field #{rpr key}" if     field_info[ 'is-multi' ]
  #.........................................................................................................
  entry[ key ] = value


#===========================================================================================================
# POPULATE DB
#-----------------------------------------------------------------------------------------------------------
@update           = ( P... ) -> return SOLR.update P...
@update_from_file = ( P... ) -> return SOLR.update_from_file P...
@commit           = ( P... ) -> return SOLR.commit P...


#===========================================================================================================
# GET BY ID
#-----------------------------------------------------------------------------------------------------------
@get = ( db, id, fallback, handler ) ->
  unless handler?
    handler   = fallback
    fallback  = undefined
  #.........................................................................................................
  return SOLR.get db, id, fallback, handler


#===========================================================================================================
# SEARCH
#-----------------------------------------------------------------------------------------------------------
@search = ( me, probes, options, handler ) ->
  return @_search me, 'search', probes, options, handler

#-----------------------------------------------------------------------------------------------------------
@count = ( me, probes, options, handler ) ->
  unless handler?
    handler = options
    options = null
  #.........................................................................................................
  options = if options? then Object.create options else {}
  options[ 'result-count' ] = 0
  #.........................................................................................................
  @_search me, 'search', probes, options, ( error, response ) ->
    return handler error if error?
    handler null, response[ 'count' ]
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@batch_search = ( me, probes, options, handler ) ->
  return @_search me, 'batch_search', probes, options, handler

#-----------------------------------------------------------------------------------------------------------
@_search = ( me, method_name, probes, options, handler ) ->
  unless handler?
    handler = options
    options = null
  #.........................................................................................................
  query = @QUERY._build ( if TYPES.isa_list probes then probes else [ probes ] )...
  #.........................................................................................................
  SOLR[ method_name ] me, query, options, ( error, response ) =>
    return handler error if error?
    #.......................................................................................................
    return handler null, null if response is null
    entries             = response[ 'results' ]
    entries[ 'count' ]  = response[ 'count'   ]
    # delete entry[ '_version_' ] for entry in entries
    handler null, entries
  #.........................................................................................................
  return null


#===========================================================================================================
# QUERY TERM ESCAPING AND QUOTING
#-----------------------------------------------------------------------------------------------------------
@escape = ( P... ) -> return SOLR.escape  P...
@quote  = ( P... ) -> return SOLR.quote   P...


#===========================================================================================================
# ENTRY FREEZING
#-----------------------------------------------------------------------------------------------------------
# @_entry_wrapper =
#   #.........................................................................................................
#   get: ( target, name ) ->
#     return true if name is '%is-wrapped'
#     return target[ name ]
#   #.........................................................................................................
#   set: ( target, name, value ) ->
#     throw new Error "object is frozen; unable to set #{rpr name}"

# #-----------------------------------------------------------------------------------------------------------
# @_freeze = ( entry ) ->
#   return Proxy entry, @_entry_wrapper





