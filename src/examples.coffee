
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


MOJIKURA.QUERY = {}


#-----------------------------------------------------------------------------------------------------------
escape_wildcard = ( text ) ->
  return text.replace /[-[\]{}()+.,\/\\^$|]/g, "\\$&"

#-----------------------------------------------------------------------------------------------------------
MOJIKURA.QUERY.term = ( term ) ->
  R     =
    '~isa':     'MOJIKURA/QUERY/term'
    'term':     term
  #.........................................................................................................
  return R

#-----------------------------------------------------------------------------------------------------------
MOJIKURA.QUERY.range = ( min, max ) ->
  return @term "[ #{min} TO #{max} ]"

#-----------------------------------------------------------------------------------------------------------
MOJIKURA.QUERY.wildcard = ( text ) ->
  R = escape_wildcard text
  ### When `/*` comes at the end of the pattern as in `foo/bar/*`, what is really meant is 'match all routes
  that are exactly `foo/bar` and all those that extend this route, as e.g. `foo/bar/baz`, but NOT
  `foo/bar-baz`': ###
  ### TAINT we have to live with the limits of the Solr/Lucene Regexes here, and this is the best i can do
  at this moment. These expressions do look like potentially leading to ungood bevaior as per
  http://www.regular-expressions.info/catastrophic.html ###
  R = R.replace /\\\/\*$/, '(\\/.+)?'
  R = R.replace /^\*\//, '(.+\\/)?'
  return new RegExp R

#-----------------------------------------------------------------------------------------------------------
MOJIKURA.QUERY.build = ( probes... ) ->
  R =
    '~isa':       'MOJIKURA/query'
    'query':      @_build probes...
  #.........................................................................................................
  return R

#-----------------------------------------------------------------------------------------------------------
MOJIKURA.QUERY._build = ( probes... ) ->
  R = []
  for probe in probes
    switch probe_type = TYPES.type_of probe
      when 'text'                 then R.push """sv:#{MOJIKURA.quote probe}"""
      when 'jsregex'              then R.push """sv:#{'/'.concat probe.source, '/'}"""
      when 'MOJIKURA/QUERY/term'  then R.push probe[ 'term' ].toString()
      #.......................................................................................................
      when 'pod'
        #.....................................................................................................
        for name, value of probe
          value_text = switch value_type = TYPES.type_of value
            when 'text'                 then  MOJIKURA.quote value
            when 'jsregex'              then  rpr value
            when 'MOJIKURA/QUERY/term'  then  value[ 'term' ].toString()
            else                              rpr value
          R.push "#{name}:#{value_text}"
        # #.....................................................................................................
        # operator_text = switch operator
        #   when 'or'   then ' OR '
        #   when 'and'  then ' AND '
        #   else throw new Error "unknown operator #{rpr operator}"
        #.....................................................................................................
  return R.join ' AND ' # operator_text
  #.........................................................................................................
  throw new Error "expected a text or a pod for a probe, got a #{probe_type}"

#-----------------------------------------------------------------------------------------------------------
MOJIKURA.QUERY.any = ( P... ) ->
  # log TRM.orange ( @build p for p in P )
  return @term ( @_build p for p in P ).join ' OR '

############################################################################################################
do ->
  ### we bind all methods of `MOJIKURA.QUERY` to the library because their anticipated use looks like

        q   = MOJIKURA.QUERY.term
        rng = MOJIKURA.QUERY.range
        ...
        MOJIKURA.search sv: '醪', pi: ( rng 0, 3 ), ( error, entries ) -> ...

  ###
  for name, value of MOJIKURA.QUERY
    MOJIKURA.QUERY[ name ] = value.bind MOJIKURA.QUERY if TYPES.isa_function value


############################################################################################################
############################################################################################################
############################################################################################################
############################################################################################################

#-----------------------------------------------------------------------------------------------------------
MOJIKURA.search = ( me, probes..., options, handler ) ->
  unless handler?
    handler = options
    options = null
  #.........................................................................................................
  query = @QUERY._build probes...
  log '©8d1', TRM.cyan query
  #.........................................................................................................
  SOLR.search me, query, options, ( error, response ) =>
    return handler error if error?
    #.......................................................................................................
    handler null, response[ 'results' ]
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
    'sort':           'sk asc, pk asc, pi asc'
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
any   = MOJIKURA.QUERY.any
all   = MOJIKURA.QUERY.all
q     = MOJIKURA.QUERY.term
rng   = MOJIKURA.QUERY.range
wild  = MOJIKURA.QUERY.wildcard
# demo_search sv: '醪', pi: ( q '[ 0 TO 3 ]' )
# demo_search sv: '醪', pi: ( rng 0, 3 )
# demo_search sv: '醪', pk: ( q '(NOT /xxx.*/)' )
# demo_search sv: '人', pk: /~has\/.*/

step ( resume ) ->*
  yield demo_search '醪', resume
  yield demo_search sv: '醪', pk: /has\/dictionary\/.*/,     resume
  yield demo_search ( any '醪', '人' ),                       resume
  yield demo_search '人', pk: ( wild 'has/dictionary/*' ),   resume
  # yield demo_search '人', pk: /has\/dictionary(\/.+)?/,   resume
                              # /has\/dictionary(\/.+)?/


test_query_builder = ->
  log TRM.rainbow MOJIKURA.QUERY.build '醪'
  log TRM.rainbow MOJIKURA.QUERY.build sv: '醪', pk: /has\/dictionary\/.*/
  log TRM.rainbow MOJIKURA.QUERY.build any '醪', '人'
  log TRM.rainbow MOJIKURA.QUERY.build '人', pk: wild 'has/dictionary/*'

test_wildcards = ->
  log TRM.rainbow wild 'helo*world'
  log TRM.rainbow wild 'has/dictionary'
  log TRM.rainbow wild 'has/dictionary*'
  log TRM.rainbow wild 'has/dictionary/*'
  log TRM.rainbow wild '*/dictionary/*'
  log TRM.rainbow 'dictionary'.match            wild 'has/dictionary/*'
  log TRM.rainbow 'has/dictionary'.match        wild 'has/dictionary/*'
  log TRM.rainbow 'has/dictionary/guide'.match  wild 'has/dictionary/*'
  log TRM.rainbow 'foo'.match                   wild '*/dictionary/*'
  log TRM.rainbow 'dictionary'.match            wild '*/dictionary/*'
  log TRM.rainbow 'has/dictionary'.match        wild '*/dictionary/*'
  log TRM.rainbow 'has/dictionary/guide'.match  wild '*/dictionary/*'
  log TRM.rainbow 'has/dictionary-guide'.match  wild '*/dictionary/*'


# https://lucene.apache.org/core/4_4_0/core/org/apache/lucene/util/automaton/RegExp.html
# http://1opensourcelover.wordpress.com/2013/09/29/solr-regex-tutorial/



# log 'foo/bar'.match new RegExp 'foo/bar'
# log 'foo/bar'.match new RegExp 'foo\/bar'
# log 'foo/bar'.match new RegExp 'foo\\/bar'


