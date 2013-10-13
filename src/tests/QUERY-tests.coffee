
############################################################################################################
TEXT                      = require 'coffeenode-text'
TYPES                     = require 'coffeenode-types'
TRM                       = require 'coffeenode-trm'
MOJIKURA                  = require '..'
QUERY                     = require './QUERY'
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
assert                    = require 'assert'
#...........................................................................................................
any                       = QUERY.any
all                       = QUERY.all
q                         = QUERY.term
range                     = QUERY.range
wild                      = QUERY.wildcard


#-----------------------------------------------------------------------------------------------------------
@test_query_builder = ( test ) ->
  assert.deepEqual ( QUERY.build '醪'                                ), {"~isa":"MOJIKURA/query","query":"sv:\"醪\""}
  assert.deepEqual ( QUERY.build sv: '醪', pk: /has\/dictionary\/.*/ ), {"~isa":"MOJIKURA/query","query":"sv:\"醪\" AND pk:/has\\/dictionary\\/.*/"}
  assert.deepEqual ( QUERY.build any '醪', '人'                       ), {"~isa":"MOJIKURA/query","query":"( sv:\"醪\" OR sv:\"人\" )"}
  assert.deepEqual ( QUERY.build all '醪', '人'                       ), {"~isa":"MOJIKURA/query","query":"( sv:\"醪\" AND sv:\"人\" )"}
  assert.deepEqual ( QUERY.build [ '醪', '人' ]                       ), {"~isa":"MOJIKURA/query","query":"( sv:\"醪\" OR sv:\"人\" )"}
  assert.deepEqual ( QUERY.build [ '醪', '人' ], ok: 'glyph'          ), {"~isa":"MOJIKURA/query","query":"( sv:\"醪\" OR sv:\"人\" ) AND ok:\"glyph\""}
  assert.deepEqual ( QUERY.build '人', pk: wild 'has/dictionary/*'   ), {"~isa":"MOJIKURA/query","query":"sv:\"人\" AND pk:/has\\/dictionary(\\/.+)?/"}
  assert.deepEqual ( QUERY.build '人', pi: ( range 0, 3 )            ), {"~isa":"MOJIKURA/query","query":"sv:\"人\" AND pi:[ 0 TO 3 ]"}
  #.........................................................................................................
  test.done()

#-----------------------------------------------------------------------------------------------------------
@test_wildcards = ( test ) ->
  assert.deepEqual ( wild 'helo*world'       ), /helo.*world/
  assert.deepEqual ( wild 'helo\\*world'     ), /helo\*world/
  assert.deepEqual ( wild 'has/dictionary'   ), /has\/dictionary/
  assert.deepEqual ( wild 'has/dictionary*'  ), /has\/dictionary.*/
  assert.deepEqual ( wild 'has/dictionary/*' ), /has\/dictionary(\/.+)?/
  assert.deepEqual ( wild '*/dictionary/*'   ), /(.+\/)?dictionary(\/.+)?/
  assert.deepEqual ( wild '*/dictionar?/*'   ), /(.+\/)?dictionar.(\/.+)?/
  #.........................................................................................................
  test.done()


############################################################################################################
test =
  done: ->


log TRM.rainbow ( QUERY.build '醪'                                )
log TRM.rainbow ( QUERY.build sv: '醪', pk: /has\/dictionary\/.*/ )
log TRM.rainbow ( QUERY.build any '醪', '人'                       )
log TRM.rainbow ( QUERY.build all '醪', '人'                       )
log TRM.rainbow ( QUERY.build [ '醪', '人' ]                       )
log TRM.rainbow ( QUERY.build [ '醪', '人' ], ok: 'glyph'          )
log TRM.rainbow ( QUERY.build '人', pk: wild 'has/dictionary/*'   )
log TRM.rainbow ( QUERY.build '人', pi: ( range 0, 3 )            )

