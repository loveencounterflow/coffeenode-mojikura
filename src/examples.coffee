
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
MOJIKURA.search = ( me, probes, options, handler ) ->
  unless handler?
    handler = options
    options = null
  #.........................................................................................................
  query = @QUERY._build ( if TYPES.isa_list probes then probes else [ probes ] )...
  log '©8d1', TRM.cyan probes
  log '©8d1', TRM.cyan options
  log '©8d1', TRM.cyan handler
  log '©8d1', TRM.cyan query
  #.........................................................................................................
  SOLR.search me, query, options, ( error, response ) =>
    return handler error if error?
    #.......................................................................................................
    entries = response[ 'results' ]
    delete entry[ '_version_' ] for entry in entries
    handler null, entries
  #.........................................................................................................
  return null

#===========================================================================================================
# ENTRIES AS TUPLES
#-----------------------------------------------------------------------------------------------------------
MOJIKURA.tuple_from_entry = ( me, entry, handler ) ->
  # log TRM.pink entry
  step ( resume ) =>*
    st  = entry[ 'st' ]
    sk  = entry[ 'sk' ]
    sv  = @get_sv me, entry
    pk  = entry[ 'pk' ]
    pi  = entry[ 'pi' ]
    ot  = entry[ 'ot' ]
    ok  = entry[ 'ok' ]
    ov  = @get_ov me, entry
    # Z   = [ [ sk, sv, ], [ pk, pi, ], [ ok, ov, ],  ]
    #.........................................................................................................
    if st is 'm'
      switch sk
        when 'entity'
          s   = yield @resolve_subject me, entry, resume
          sk  = s[ 'sk' ]
          sv  = @get_sv me, s
        when 'phrase', 'relation'
          s   = yield @resolve_subject  me, entry, resume
          sv  = yield @tuple_from_entry me, s, resume
        else
          throw new Error "unknown meta key: #{rpr sk}"
    #.........................................................................................................
    if ot is 'm'
      switch ok
        when 'entity'
          o   = yield @resolve_object   me, entry, resume
          ok  = o[ 'sk' ]
          ov  = @get_sv me, o
        when 'phrase', 'relation'
          o   = yield @resolve_object   me, entry, resume
          ov  = yield @tuple_from_entry me, o, resume
        else
          throw new Error "unknown meta key: #{rpr sk}"
    #.........................................................................................................
    s = [ sk, sv, ]
    p = [ pk, pi, ]
    o = [ ok, ov, ]
    #.........................................................................................................
    handler null, [ s, p, o, ]
    #.........................................................................................................
    return null


############################################################################################################


#-----------------------------------------------------------------------------------------------------------
demo_search = ( probes..., handler ) ->
  db = MOJIKURA.new_db()
  #.........................................................................................................
  options =
    'result-count':   500
    'sort':           'sk asc, sv asc, pk asc, pi asc'
  #.........................................................................................................
  step ( resume ) =>*
    log()
    log TRM.steel probes
    entries = yield MOJIKURA.search db, probes..., options, resume
    #.......................................................................................................
    for entry in entries
      entry_tuple = yield MOJIKURA.tuple_from_entry db, entry, resume
      #.....................................................................................................
      [ [ sk, sv ], [ pk, pi ], [ ok, ov ] ] = entry_tuple
      log TRM.rainbow \
        TRM.grey      sk,
        TRM.crimson   sv,
        TRM.orange    pk,
        TRM.grey      pi,
        TRM.grey      ok,
        TRM.crimson   ov,
    #.......................................................................................................
    handler null

#===========================================================================================================
QUERY = MOJIKURA.QUERY
any   = QUERY.any
all   = QUERY.all
q     = QUERY.term
rng   = QUERY.range
wild  = QUERY.wildcard
regex = QUERY.regex
# demo_search sv: '醪', pi: ( q '[ 0 TO 3 ]' )
# demo_search sv: '醪', pi: ( rng 0, 3 )
# demo_search sv: '醪', pk: ( q '(NOT /xxx.*/)' )
# demo_search sv: '人', pk: /~has\/.*/

# step ( resume ) ->*
  # yield demo_search '醪', resume
  # yield demo_search sv: '醪', pk: /has\/dictionary\/.*/,     resume
  # yield demo_search ( any '醪', '人' ),                       resume
  # yield demo_search '人', pk: ( wild 'has/dictionary/*' ),   resume
  # yield demo_search '人', pk: ( wild 'has/reading/py/*' ),   resume
  # yield demo_search '醪', pk: ( wild 'has/*/component' ),   resume

f = ->
  db = MOJIKURA.new_db()
  #.........................................................................................................
  options =
    'result-count':   5000
    'sort':           'sk asc, sv asc, pk asc, pi asc'
  #.........................................................................................................
  step ( resume ) =>*
    # entries     = yield MOJIKURA.search db, '醪', pk: 'has/shape/breakdown/component', options, resume
    # log TRM.cyan entries
    # components  = ( entry[ 'ov' ] for entry in entries )
    components  = [ '食', ]
    components  = [ '糸', ]
    components  = [ '井', ]
    ov_matcher  = regex components.join '|'
    query       = pk: 'has/shape/breakdown/component', 'ov': ( regex components.join '|' )
    entries_1   = yield MOJIKURA.search db, query, options, resume
    # log TRM.pink entries_1
    glyphs      = ( entry[ 'sv' ] for entry in entries_1 )
    log glyphs.join ' '
    log glyphs.length

# do f

# https://lucene.apache.org/core/4_4_0/core/org/apache/lucene/util/automaton/RegExp.html
# http://1opensourcelover.wordpress.com/2013/09/29/solr-regex-tutorial/



#-----------------------------------------------------------------------------------------------------------
ng_update = ->
  db      = MOJIKURA.new_db()
  method  = 'post'
  #.........................................................................................................
  entry =
    id:       'glyph/經'
    # sk:       'glyph'
    # sv:       '經'
    # pk:       { set: null, }
    # 'out/has/component':  { set: null }
    'out/has/component':  { set: [ 'glyph/糸', 'glyph/工', ] }
  #.........................................................................................................
  options =
    url:      db[ 'urls' ][ 'update' ]
    json:     true
    body:     [ entry, ]
    qs:
      commit: true
      wt:     'json'
  #.........................................................................................................
  step ( resume ) =>*
    response = yield SOLR._query db, method, options, resume
    log TRM.orange response

# do ng_update
test_ng_entries = ->
  db = MOJIKURA.new_db()
  log TRM.rainbow 經 = MOJIKURA.new_node db, null, 'glyph', '經'
  log TRM.rainbow 糹 = MOJIKURA.new_node db, null, 'glyph', '糹'
  log TRM.rainbow 巠 = MOJIKURA.new_node db, null, 'glyph', '巠'
  log TRM.rainbow 工 = MOJIKURA.new_node db, null, 'glyph', '工'
  log TRM.rainbow formula = MOJIKURA.new_node db, null, 'shape/breakdown/formula', '⿰糹巠'

  log()
  MOJIKURA.connect db, 經, 'has/shape/component', 糹
  log TRM.rainbow 經
  MOJIKURA.connect db, 經, 'has/shape/component', 工
  log TRM.rainbow 經
  MOJIKURA.connect db, formula, 'has/shape/component', 工
  MOJIKURA.connect db, formula, 'has/shape/component', 糹

  log()
  log TRM.rainbow 糹
  log TRM.rainbow 工
  log TRM.rainbow formula

search = ->
  step ( resume ) ->*
    db = MOJIKURA.new_db()
    entries = yield MOJIKURA.search db, '衷', resume
    log TRM.rainbow entry for entry in entries
    entries = yield MOJIKURA.search db, '中', resume
    log TRM.rainbow entry for entry in entries
    entries = yield MOJIKURA.search db, k: 'glyph', resume
    log TRM.rainbow entry for entry in entries

do ->
  db = MOJIKURA.new_db()
  log TRM.rainbow 經 = MOJIKURA.new_node db, 'i', 'dictionary/idx', 24


