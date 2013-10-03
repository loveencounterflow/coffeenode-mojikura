
############################################################################################################
TEXT                      = require 'coffeenode-text'
TYPES                     = require 'coffeenode-types'
TRM                       = require 'coffeenode-trm'
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
escape_wildcard = ( text ) ->
  return text.replace /[-[\]{}()+.,\/\\^$|]/g, "\\$&"

#-----------------------------------------------------------------------------------------------------------
@term = ( term ) ->
  R     =
    '~isa':     'MOJIKURA/QUERY/term'
    'term':     term
  #.........................................................................................................
  return R

#-----------------------------------------------------------------------------------------------------------
@range = ( min, max ) ->
  return @term "[ #{min} TO #{max} ]"

#-----------------------------------------------------------------------------------------------------------
@regex = ( x ) ->
  return x if TYPES.isa_jsregex x
  return new RegExp x

#-----------------------------------------------------------------------------------------------------------
@wildcard = ( text ) ->
  R = escape_wildcard text
  ### When `/*` comes at the end of the pattern as in `foo/bar/*`, what is really meant is 'match all routes
  that are exactly `foo/bar` and all those that extend this route, as e.g. `foo/bar/baz`, but NOT
  `foo/bar-baz`': ###
  ### TAINT we have to live with the limitations of the Solr/Lucene Regexes here, and this is the best i can
  do at this moment. These expressions do look like potentially leading to ungood behavior as per
  http://www.regular-expressions.info/catastrophic.html ###
  R = R.replace /(\\\\)?\?/g, ( match ) -> return if match[ 0 ] is '\\' then '\\?' else '.'
  R = R.replace /\\\/\*$/,    '(\\/.+)?'
  R = R.replace /^\*\\\//,    '(.+\\/)?'
  R = R.replace /(\\\\)?\*/g, ( match ) -> return if match[ 0 ] is '\\' then '\\*' else '.*'
  return new RegExp R

#-----------------------------------------------------------------------------------------------------------
@build = ( probes... ) ->
  R =
    '~isa':       'MOJIKURA/query'
    'query':      @_build probes...
  #.........................................................................................................
  return R

#-----------------------------------------------------------------------------------------------------------
@_build = ( probes... ) ->
  R = []
  for probe in probes
    switch probe_type = TYPES.type_of probe
      #.....................................................................................................
      when 'list'
        R.push '( '.concat ( @_any probe ), ' )'
      #.....................................................................................................
      when 'pod'
        #...................................................................................................
        for key, value of probe
          R.push "#{@escape_key key}:#{@_build_simple_value value}"
      #.....................................................................................................
      when 'MOJIKURA/QUERY/term'
        R.push '( '.concat probe[ 'term' ].toString(), ' )'
      #.....................................................................................................
      else
        R.push """v:#{@_build_simple_value probe}"""
  #.........................................................................................................
  return R.join ' AND '

#-----------------------------------------------------------------------------------------------------------
@_build_simple_value = ( probe ) ->
  switch probe_type = TYPES.type_of probe
    when 'text'                 then return MOJIKURA.quote probe
    when 'number'               then return rpr probe
    when 'boolean'              then return rpr probe
    when 'jsregex'              then return '/'.concat probe.source, '/'
    when 'MOJIKURA/QUERY/term'  then return probe[ 'term' ].toString()
  #.........................................................................................................
  throw new Error "unknown query probe type: #{probe_type}"

#-----------------------------------------------------------------------------------------------------------
@any    = ( P... )        -> return @term @_any P
@all    = ( P... )        -> return @term @_all P
@_any   = ( P )           -> return @_join P, ' OR '
@_all   = ( P )           -> return @_join P, ' AND '
@_join  = ( P, operator ) -> return ( @_build p for p in P ).join operator

#-----------------------------------------------------------------------------------------------------------
@escape_key   = ( key   ) -> return MOJIKURA.escape key
@escape_value = ( value ) -> return MOJIKURA.escape value


############################################################################################################
QUERY = @
do ->
  ### we bind all methods of `MOJIKURA.QUERY` to the library because their anticipated use looks like

        q   = @term
        rng = @range
        ...
        MOJIKURA.search v: '醪', pi: ( rng 0, 3 ), ( error, entries ) -> ...

  ###
  for name, value of QUERY
    QUERY[ name ] = value.bind QUERY if TYPES.isa_function value

