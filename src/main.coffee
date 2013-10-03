


############################################################################################################
njs_os                    = require 'os'
njs_fs                    = require 'fs'
njs_path                  = require 'path'
njs_crypto                = require 'crypto'
#...........................................................................................................
TEXT                      = require 'coffeenode-text'
SOLR                      = require 'coffeenode-solr'
# POSTER                    = require './POSTER'
TYPES                     = require 'coffeenode-types'
TRM                       = require 'coffeenode-trm'
CHR                       = require 'coffeenode-chr'
log                       = TRM.log.bind TRM
rpr                       = TRM.rpr.bind TRM
echo                      = TRM.echo.bind TRM
#...........................................................................................................
### used to enable proxies; see https://github.com/tvcutsem/harmony-reflect ###
require 'harmony-reflect'
#...........................................................................................................
suspend                   = require 'coffeenode-suspend'
# step                      = suspend.step
# collect                   = suspend.collect
immediately               = setImmediate
eventually                = process.nextTick
#...........................................................................................................
@QUERY                    = require './QUERY'
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
  R[ '~isa' ] = 'MOJIKURA/db'
  return R


#===========================================================================================================
# ENTRY DELETION
#-----------------------------------------------------------------------------------------------------------
@clear = ( db, handler ) ->
  return SOLR.clear db, handler


#===========================================================================================================
# ENTRY CREATION
#-----------------------------------------------------------------------------------------------------------
@new_node = ( me, t, k, v ) ->
  #.........................................................................................................
  R =
    '~isa':         'MOJIKURA/node'
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
@connect = ( me, s, p, o ) ->
  ( s[ 'out:'.concat p ]?= [] ).push o[ 'id' ]
  ( o[  'in:'.concat p ]?= [] ).push s[ 'id' ]
  return null

# #-----------------------------------------------------------------------------------------------------------
# @sv_name_from_st  = ( me, st ) -> return if st? and st.length > 0 then 'sv'.concat '.', st else 'sv'
# @ov_name_from_ot  = ( me, ot ) -> return if ot? and ot.length > 0 then 'ov'.concat '.', ot else 'ov'
# #...........................................................................................................
# @get_sv           = ( me, entry ) -> return entry[ @sv_name_from_st me, entry[ 'st' ] ]
# @get_ov           = ( me, entry ) -> return entry[ @ov_name_from_ot me, entry[ 'ot' ] ]


# #===========================================================================================================
# # PHRASE MATCHING
# #-----------------------------------------------------------------------------------------------------------
# id_matcher          = /// (?: \| [^ | ]+ \| ) ///
# type_sigil_matcher  = /// (?: \( [^ \s () ]+ \) ) ///
# key_matcher         = /// (?: \\[ : , ] | [^ : , ]* ) ///
# index_matcher       = /// (?: [ 0-9 ]+ ) ///
# simplex_matcher     = /// (?: null | true | false ) ///
# number_matcher      = /// (?: -?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)? ) ///
# text_matcher        = /// (?: " (?: \\" | [^"] )* " ) ///
# #...........................................................................................................
# value_matcher       = /// (?:
#   #{simplex_matcher.source} |
#   #{number_matcher.source}  |
#   #{text_matcher.source}    | ) ///
# #...........................................................................................................
# phrase_matcher = ///
#   ( #{id_matcher.source}? )
#   ( #{type_sigil_matcher.source}? ) ( #{key_matcher.source} ) : ( #{value_matcher.source} ) ,
#                                     ( #{key_matcher.source} ) : ( #{index_matcher.source} ) ,
#   ( #{type_sigil_matcher.source}? ) ( #{key_matcher.source} ) : ( #{value_matcher.source} ) $ ///


# #===========================================================================================================
# # SERIALIZATION / PHRASE CONSTRUCTION
# #-----------------------------------------------------------------------------------------------------------
# @_rpr_of_subject  = \
# @_rpr_of_object   = ( type_sigil, key, value ) ->
#   type_rpr  = if type_sigil? and type_sigil.length > 0 then '('.concat type_sigil, ')' else ''
#   key_rpr   = if key?   then @_escape_key key else ''
#   value_rpr = if value? then JSON.stringify value else ''
#   return type_rpr.concat key_rpr, ':', value_rpr

# #-----------------------------------------------------------------------------------------------------------
# @_rpr_of_predicate = ( key, idx ) ->
#   return ( if key? then @_escape_key key else '' ).concat ':', JSON.stringify idx

# #-----------------------------------------------------------------------------------------------------------
# @_escape_key = ( key ) ->
#   return key.replace /([:,])/g, '\\$1'

# #-----------------------------------------------------------------------------------------------------------
# @_unescape_key = ( key ) ->
#   return key.replace /(\\[:,])/g, '$1'

#-----------------------------------------------------------------------------------------------------------
@rpr_of_entry = ( entry, with_id = no ) ->
  throw new Error "not implemented"
#   #.........................................................................................................
#   sk          = entry[ 'sk' ]
#   st          = entry[ 'st' ]
#   sv_name     = @sv_name_from_st null, st
#   sv          = entry[ sv_name ]
#   #.........................................................................................................
#   pk          = entry[ 'pk' ]
#   #.........................................................................................................
#   ok          = entry[ 'ok' ]
#   ot          = entry[ 'ot' ]
#   ov_name     = @ov_name_from_ot null, ot
#   ov          = entry[ ov_name ]
#   #.........................................................................................................
#   [ id
#     t
#     n ]  = @_id_type_and_fieldname_from_facet null, k, v
#   return unless with_id then phrase else '|'.concat id, '|', phrase

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

#-----------------------------------------------------------------------------------------------------------
@rpr_of_db = ( db ) ->
  throw new Error "not implemented"

#-----------------------------------------------------------------------------------------------------------
@rpr = ( x ) ->
  switch type = TYPES.type_of x
    when 'MOJIKURA/entry' then return @rpr_of_entry x
    when 'MOJIKURA/db'    then return @rpr_of_db    x
  throw new Error "expected a MojiKura entry or DB, got a #{type}"


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

#-----------------------------------------------------------------------------------------------------------
@search = ( P... ) -> return SOLR.search P...


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





