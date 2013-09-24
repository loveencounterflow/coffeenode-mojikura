


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
### used to enable proxies; see https://github.com/tvcutsem/harmony-reflect ###
require 'harmony-reflect'
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
@new_entry = ( me, P... ) ->
  switch arity = P.length
    when 1                then return @new_entry_from_phrase me, P[ 0 ]
    when 3, 4, 5, 6, 7, 8 then return @new_entry_from_pos    me, P...
    else throw new Error "unexpected arity #{arity}"

#-----------------------------------------------------------------------------------------------------------
@new_entry_from_phrase = ( me, phrase ) ->
  match = phrase.match phrase_matcher
  throw new Error "unable to parse phrase: #{rpr phrase}" unless match?
  [ ignored, id, st, sk, sv, pk, pi, ot, ok, ov ] = match
  st = if st? and st.length isnt 0 then st.replace /[()]/g, '' else null
  ot = if ot? and ot.length isnt 0 then ot.replace /[()]/g, '' else null
  ### TAINT empty sv not allowed ###
  sv = if sv? and sv.length > 0 then JSON.parse sv else null
  ov = if ov? and ov.length > 0 then JSON.parse ov else null
  return @_new_entry_from_pos me, st, sk, sv, pk, pi, ot, ok, ov, phrase

#-----------------------------------------------------------------------------------------------------------
@new_entry_from_pos = ( me, st, sk, sv, pk, pi, ot, ok, ov, phrase ) ->
  throw new Error "need a subject key"    unless sk?
  throw new Error "need a subject value"  unless sv?
  #.........................................................................................................
  R =
    '~isa':         'MOJIKURA/entry'
  #.........................................................................................................
  sv_name     = if st? and st.length > 0 then 'sv'.concat '.', st else 'sv'
  ov_name     = if ot? and ot.length > 0 then 'ov'.concat '.', ot else 'ov'
  #.........................................................................................................
  if pi?
    pi = JSON.parse pi if TYPES.isa_text pi
  else
    pi = 0
  #.........................................................................................................
  if phrase?
    id = @_hash phrase
  else
    [ id
      phrase ]  = @_id_and_rpr_from_pos st, sk, sv, pk, pi, ot, ok, ov
  #.........................................................................................................
  R[ 'id' ]     = id
  R[ 'sk' ]     = sk
  R[ 'st' ]     = st if st? and st.length isnt 0
  R[ sv_name  ] = sv
  R[ 'pk' ]     = pk if pk? and pk.length isnt 0
  R[ 'pi' ]     = pi
  R[ 'ok' ]     = ok if ok? and ok.length isnt 0
  R[ 'ot' ]     = ot if ot?
  R[ ov_name ]  = ov if ov? and ov.length isnt 0
  #.........................................................................................................
  return @_freeze R


#===========================================================================================================
# PHRASE MATCHING
#-----------------------------------------------------------------------------------------------------------
id_matcher          = /// (?: \| [^ | ]+ \| ) ///
type_sigil_matcher  = /// (?: \( [^ \s () ]+ \) ) ///
key_matcher         = /// (?: \\[ : , ] | [^ : , ]* ) ///
index_matcher       = /// (?: [ 0-9 ]+ ) ///
simplex_matcher     = /// (?: null | true | false ) ///
number_matcher      = /// (?: -?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)? ) ///
text_matcher        = /// (?: " (?: \\" | [^"] )* " ) ///
#...........................................................................................................
value_matcher       = /// (?:
  #{simplex_matcher.source} |
  #{number_matcher.source}  |
  #{text_matcher.source}    | ) ///
#...........................................................................................................
phrase_matcher = ///
  ( #{id_matcher.source}? )
  ( #{type_sigil_matcher.source}? ) ( #{key_matcher.source} ) : ( #{value_matcher.source} ) ,
                                    ( #{key_matcher.source} ) : ( #{index_matcher.source} ) ,
  ( #{type_sigil_matcher.source}? ) ( #{key_matcher.source} ) : ( #{value_matcher.source} ) $ ///


#===========================================================================================================
# SERIALIZATION / PHRASE CONSTRUCTION
#-----------------------------------------------------------------------------------------------------------
@_rpr_of_subject  = \
@_rpr_of_object   = ( type_sigil, key, value ) ->
  type_rpr  = if type_sigil? and type_sigil.length > 0 then '('.concat type_sigil, ')' else ''
  key_rpr   = if key?   then @_escape_key key else ''
  value_rpr = if value? then JSON.stringify value else ''
  return type_rpr.concat key_rpr, ':', value_rpr

#-----------------------------------------------------------------------------------------------------------
@_rpr_of_predicate = ( key, idx ) ->
  return ( if key? then @_escape_key key else '' ).concat ':', JSON.stringify idx

#-----------------------------------------------------------------------------------------------------------
@_escape_key = ( key ) ->
  return key.replace /([:,])/g, '\\$1'

#-----------------------------------------------------------------------------------------------------------
@_unescape_key = ( key ) ->
  return key.replace /(\\[:,])/g, '$1'

#-----------------------------------------------------------------------------------------------------------
@rpr_of_entry = ( entry, with_id = no ) ->
  #.........................................................................................................
  sk          = entry[ 'sk' ]
  st          = entry[ 'st' ]
  sv_name     = if st? and st.length > 0 then 'sv'.concat '.', st else 'sv'
  sv          = entry[ sv_name ]
  #.........................................................................................................
  pk          = entry[ 'pk' ]
  pi          = entry[ 'pi' ]
  #.........................................................................................................
  ok          = entry[ 'ok' ]
  ot          = entry[ 'ot' ]
  ov_name     = if ot? and ot.length > 0 then 'ov'.concat '.', ot else 'ov'
  ov          = entry[ ov_name ]
  #.........................................................................................................
  [ id
    phrase ]  = @_id_and_rpr_from_pos st, sk, sv, pk, pi, ot, ok, ov
  return unless with_id then phrase else '|'.concat id, '|', phrase

#-----------------------------------------------------------------------------------------------------------
@_id_and_rpr_from_pos = ( st, sk, sv, pk, pi, ot, ok, ov ) ->
  #.........................................................................................................
  subject_rpr   = @_rpr_of_subject   st, sk, sv
  predicate_rpr = @_rpr_of_predicate     pk, pi
  object_rpr    = @_rpr_of_object    ot, ok, ov
  #.........................................................................................................
  phrase        = subject_rpr.concat ',', predicate_rpr, ',', object_rpr
  id            = @_hash phrase
  #.........................................................................................................
  return [ id, phrase, ]

#-----------------------------------------------------------------------------------------------------------
@_hash = ( text ) ->
  ### TAINT: hash characteristics should go to options ###
  ### TAINT: should use xxhash where available ###
  # hash_name = 'rsa-sha512'
  # hash_name = 'sha1'
  # hash_name = 'md5'
  hash_name = 'sha256'
  hash_size = 12
  return ( ( ( njs_crypto.createHash hash_name ).update text, 'utf-8' ).digest 'hex' ).substr 0, hash_size

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
  #   ### JavaScript's way of saying `list.remove idx` ###
  #   if entry[ '%is-clean' ] then  entries.splice idx, 1
  #   else                          @_cast_to_db db, entry
  # ### KLUDGE: prevent this same iteration from being repeated in SOLR.update: ###
  # entries[ '%dont-modify' ] = yes
  #.........................................................................................................
  SOLR.update db, entries, ( error, response ) =>
    throw error if error?
    # @_cast_from_db db, entry for entry in entries
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
    # @_cast_from_db db, Z unless Z is fallback
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
    # @_cast_from_db db, entry for entry in results
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


# #===========================================================================================================
# # ENTRY CASTING
# #-----------------------------------------------------------------------------------------------------------
# @_cast_from_db = ( db, entry, value ) ->
#   return entry unless ( format = entry[ 'format' ] )?
#   throw new Error "unknown casting format #{rpr format}" unless format is 'json'
#   delete entry[ 'format' ]
#   entry[ 'value' ] = value ? JSON.parse entry[ 'value' ]
#   return entry
#   # #.........................................................................................................
#   # return entry if entry[ 'isa' ] isnt 'node'
#   # return entry if entry[ 'is-live' ]
#   # if format = entry[ 'format' ] is 'json'
#   #   entry[ 'value' ] = JSON.parse entry[ 'value' ]
#   # else
#   #   decode = db[ 'formats' ]?[ format ]?[ 'decode' ]
#   #   throw new Error "unregistered format #{rpr format}" unless decode?
#   #   entry[ 'value' ] = decode entry[ 'value' ]
#   # entry[ 'is-live' ] = yes
#   # return entry

# #-----------------------------------------------------------------------------------------------------------
# @_cast_to_db = ( db, entry ) ->
#   # log '©5p1', TRM.pink entry
#   return entry if entry[ 'isa' ] isnt 'node'
#   return entry if ( format = entry[ 'format' ] ) is 'json'
#   return entry if ( TYPES.type_of entry[ 'value' ] ) is 'text'
#   throw new Error "unknown casting format #{rpr format}" if format?
#   entry[ 'format' ] = 'json'
#   entry[ 'value'  ] = JSON.stringify entry[ 'value' ]
#   return entry
#   # #.........................................................................................................
#   # return entry if entry[ 'isa' ] isnt 'node'
#   # delete entry[ 'is-live' ]
#   # return entry

#===========================================================================================================
# QUERY TERM ESCAPING AND QUOTING
#-----------------------------------------------------------------------------------------------------------
@escape = ( P... ) -> return SOLR.escape  P...
@quote  = ( P... ) -> return SOLR.quote   P...


#===========================================================================================================
# ENTRY FREEZING
#-----------------------------------------------------------------------------------------------------------
@_entry_wrapper =
  #.........................................................................................................
  get: ( target, name ) ->
    return true if name is '%is-wrapped'
    return target[ name ]
  #.........................................................................................................
  set: ( target, name, value ) ->
    throw new Error "object is frozen; unable to set #{rpr name}"

#-----------------------------------------------------------------------------------------------------------
@_freeze = ( entry ) ->
  return Proxy entry, @_entry_wrapper





