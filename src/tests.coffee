

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
MJK                       = require '..'
log                       = TRM.log.bind TRM
rpr                       = TRM.rpr.bind TRM
echo                      = TRM.echo.bind TRM
#...........................................................................................................
suspend                   = require 'coffeenode-suspend'
step                      = suspend.step
collect                   = suspend.collect
immediately               = setImmediate
#...........................................................................................................
# NanoTimer                 = require 'nanotimer'
get_ts_tns                = -> return process.hrtime()
get_dt_dtns               = ( ts_tns0 ) ->
  ts_tns1 = get_ts_tns()
  return [ ts_tn1[ 0 ] - ts_tns0[ 0 ], ts_tn1[ 1 ] - ts_tns0[ 1 ] ]

#-----------------------------------------------------------------------------------------------------------
@_cache_formula_glyphs_by_glyph = {}

#-----------------------------------------------------------------------------------------------------------
@analyze_formula = ( db, glyph, handler ) ->
  pending_glyphs  = [ glyph, ]
  Z               = []
  #=========================================================================================================
  step ( resume ) =>*
    glyph_id    = MJK.get_node_id db, 'glyph', glyph
    glyph_entry = yield MJK.get db, glyph_id, null, resume
    query       = """isa:"edge" AND from:#{MJK.quote glyph_id} AND key:"has/shape/breakdown/formula" """
    response    = yield MJK.search db, query, 'result-count': 1e6, resume
    edges       = response[ 'results' ]
    #.......................................................................................................
    for edge in edges
      formula_id    = edge[ 'to' ]
      formula_edge  = yield MJK.get db, formula_id, null, resume
      if formula_edge?
        formula         = formula_edge[ 'value' ]
        #...................................................................................................
        if formula is '●' or formula is '〓'
          @_cache_formula_glyphs_by_glyph[ glyph ] = null
          continue
        #...................................................................................................
        if @_cache_formula_glyphs_by_glyph
        formula_glyphs  = CHR.chrs_from_text formula, input: 'xncr'
        for formula_glyph in formula_glyphs
          continue if ( formula_glyph.match /// [ () ⿰⿱⿲⿳⿴⿵⿶⿷⿸⿹⿺⿻ ◰ ● 〓 ] /// )?
          log TRM.red formula_glyph
          yield @analyze_formula db, formula_glyph, resume
    #.......................................................................................................
    handler null, response

    # #.......................................................................................................
    # for edge_entry in response[ 'results' ]
    #   # @_cast_from_db db, entry
    #   # log TRM.rainbow entry
    #   to_id     = edge_entry[ 'to' ]
    #   sub_entry = yield MJK.get db, to_id, null, resume
    #   log TRM.rainbow '(', glyph_entry[ 'key' ], ')', glyph_entry[ 'value' ], '--', edge_entry[ 'key' ], '-> (', sub_entry[ 'key' ], ')', sub_entry[ 'value' ]
    # #.......................................................................................................
    # # MJK.log_cache_report db
    # handler null, null


#===========================================================================================================
# QUERY
#-----------------------------------------------------------------------------------------------------------
@query = ( db, glyph, handler ) ->
  #=========================================================================================================
  step ( resume ) =>*
    glyph_entry = yield MJK.get db, "glyph/#{glyph}", null, resume
    response    = yield MJK.search db, """isa:"edge" AND from:"glyph/#{glyph}" """, resume
    # log()
    # log TRM.yellow "query took #{response[ 'dt' ]}ms"
    #.......................................................................................................
    for edge_entry in response[ 'results' ]
      # @_cast_from_db db, entry
      # log TRM.rainbow entry
      to_id     = edge_entry[ 'to' ]
      sub_entry = yield MJK.get db, to_id, null, resume
      log TRM.rainbow '(', glyph_entry[ 'key' ], ')', glyph_entry[ 'value' ], '--', edge_entry[ 'key' ], '-> (', sub_entry[ 'key' ], ')', sub_entry[ 'value' ]
    #.......................................................................................................
    # MJK.log_cache_report db
    handler null, null

#-----------------------------------------------------------------------------------------------------------
@query2 = ( db ) ->
  step ( resume ) =>*
    entry = yield MJK.get db, 'glyph/鼇', null, resume
    log TRM.yellow entry
    MJK.log_cache_report db

# MJK = @

# MJK.populate db, ( get_entries db ), ( error, response ) ->
#   throw error if error?
#   # log TRM.yellow response
#   MJK.query db

# MJK.query2 db
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
    # log MJK._cast_to_db db, entries[ 2 ]

#-----------------------------------------------------------------------------------------------------------
@test_formula_analysis = ->
  db    = MJK.new_db()
  glyph = '燕'
  #=========================================================================================================
  step ( resume ) =>*
    results = yield @analyze_formula db, glyph, resume
    log TRM.pink results

# do @main
do @test_formula_analysis



