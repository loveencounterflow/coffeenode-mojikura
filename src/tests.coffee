

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
#...........................................................................................................



#===========================================================================================================
# QUERY
#-----------------------------------------------------------------------------------------------------------
@query = ( db, glyph, handler ) ->
  #=========================================================================================================
  step ( resume ) =>*
    glyph_entry = yield MOJIKURA.get db, "glyph/#{glyph}", null, resume
    response    = yield MOJIKURA.search db, """isa:"edge" AND from:"glyph/#{glyph}" """, resume
    # log()
    # log TRM.yellow "query took #{response[ 'dt' ]}ms"
    #.......................................................................................................
    for edge_entry in response[ 'results' ]
      # @_cast_from_db db, entry
      # log TRM.rainbow entry
      to_id     = edge_entry[ 'to' ]
      sub_entry = yield MOJIKURA.get db, to_id, null, resume
      log TRM.rainbow '(', glyph_entry[ 'key' ], ')', glyph_entry[ 'value' ], '--', edge_entry[ 'key' ], '-> (', sub_entry[ 'key' ], ')', sub_entry[ 'value' ]
    #.......................................................................................................
    # MOJIKURA.log_cache_report db
    handler null, null

#-----------------------------------------------------------------------------------------------------------
@query2 = ( db ) ->
  step ( resume ) =>*
    entry = yield MOJIKURA.get db, 'glyph/鼇', null, resume
    log TRM.yellow entry
    MOJIKURA.log_cache_report db

# MOJIKURA = @
db = MOJIKURA.new_db()

# MOJIKURA.populate db, ( get_entries db ), ( error, response ) ->
#   throw error if error?
#   # log TRM.yellow response
#   MOJIKURA.query db

# MOJIKURA.query2 db
# log get_entries db

@main = ->
  step ( resume ) =>*
    glyphs = CHR.chrs_from_text """國國或北京，簡稱京，係中華人民共和國嘅首都，有過千年歷史1153年，金朝設中都，是為北京建
    都之始，2013年是北京建都860周年[3]。金中都人口超過一百萬。金中都為元、明、清三代的北京城的建設奠定了基礎。
    北京位於華北平原的西北邊緣，背靠燕山，有永定河流經老城西南，毗鄰天津市、河北省，是一座有三千餘年建城歷史、
    八百六十餘年建都史的歷史文化名城，歷史上有金、元、明、清、中華民國（北洋政府時期）等五個朝代在此定都，以及數個政權建政於此，
    薈萃了自元明清以來的中華文化，擁有眾多歷史名勝古迹和人文景觀。"""
    for glyph in glyphs
      yield @query db, glyph, resume
    # log MOJIKURA._cast_to_db db, entries[ 2 ]

do @main
