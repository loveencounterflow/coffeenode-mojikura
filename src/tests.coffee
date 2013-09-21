

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
# @_cache_formula_glyphs_by_glyph = {}

#-----------------------------------------------------------------------------------------------------------
@get_all = ( db ) ->
  #=========================================================================================================
  step ( resume ) =>*
    query       = """*:*"""
    response    = yield MJK.search db, query, 'result-count': 1e9, resume
    log "retrieved #{response[ 'results' ].length} entries"
    log "dt: #{response[ 'dt' ]}ms"

#-----------------------------------------------------------------------------------------------------------
@analyze_formula = ( db, glyph, handler ) ->
  # log TRM.cyan glyph
  echo glyph
  return @_analyze_formula db, glyph, 1, null, handler

#-----------------------------------------------------------------------------------------------------------
@_analyze_formula = ( db, glyph, level, cache, handler ) ->
  cache          ?= {}
  # pending_glyphs  = [ glyph, ]
  Z               = []
  #=========================================================================================================
  step ( resume ) =>*
    glyph_id    = MJK.get_node_id db, 'glyph', glyph
    glyph_entry = yield MJK.get db, glyph_id, null, resume
    query       = """isa:"edge" AND from:#{MJK.quote glyph_id} AND key:"has/shape/breakdown/formula" """
    response    = yield MJK.search db, query, 'result-count': 1e6, resume
    edges       = response[ 'results' ]
    # log TRM.steel edges
    #.......................................................................................................
    for edge in edges
      formula_id    = edge[ 'to' ]
      formula_edge  = yield MJK.get db, formula_id, null, resume
      #.....................................................................................................
      if formula_edge?
        formula         = formula_edge[ 'value' ]
        #...................................................................................................
        if formula is '●' or formula is '〓'
          # @_cache_formula_glyphs_by_glyph[ glyph ] = null
          continue
        #...................................................................................................
        # if @_cache_formula_glyphs_by_glyph
        formula_glyphs  = CHR.chrs_from_text formula, input: 'xncr'
        for formula_glyph in formula_glyphs
          continue if ( formula_glyph.match /// [ () ⿰⿱⿲⿳⿴⿵⿶⿷⿸⿹⿺⿻ ◰ ● 〓 ] /// )?
          indentation = ( new Array level + 1 ).join '\t'
          # log TRM.red indentation, formula_glyph
          echo indentation + formula_glyph
          yield @_analyze_formula db, formula_glyph, level + 1, cache, resume
      #.....................................................................................................
      else
        log TRM.grey "no endpoint found for #{rpr edge}"
    #.......................................................................................................
    handler null, response

    # # #.......................................................................................................
    # # for edge_entry in response[ 'results' ]
    # #   # @_cast_from_db db, entry
    # #   # log TRM.rainbow entry
    # #   to_id     = edge_entry[ 'to' ]
    # #   sub_entry = yield MJK.get db, to_id, null, resume
    # #   log TRM.rainbow '(', glyph_entry[ 'key' ], ')', glyph_entry[ 'value' ], '--', edge_entry[ 'key' ], '-> (', sub_entry[ 'key' ], ')', sub_entry[ 'value' ]
    # # #.......................................................................................................
    # # # MJK.log_cache_report db
    # # handler null, null


#===========================================================================================================
# QUERY
#-----------------------------------------------------------------------------------------------------------
@query_test_entries = ( db ) ->
  #=========================================================================================================
  step ( resume ) =>*
    test_entries = yield MJK.search db, """isa:"node" AND key:/test\\/.*/ """, resume
    log '©7z6', TRM.pink test_entries

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
@query2 = ( test ) ->
  ### TAINT should be `MJK.new_db` ###
  db = SOLR.new_db()
  step ( resume ) =>*
    # MJK.  http://localhost:8983/solr/select?q=isa:%22node%22%20AND%20key:%22glyph%22%20AND%20value:%22%E5%9C%8B%22&wt=xml&rows=100
    entry = yield MJK.get db, 'glyph/鼇', null, resume
    log TRM.yellow entry
    MJK.log_cache_report db
    test.done()

# MJK = @

# MJK.populate db, ( get_entries db ), ( error, response ) ->
#   throw error if error?
#   # log TRM.yellow response
#   MJK.query db

# MJK.query2 db
# log get_entries db

#-----------------------------------------------------------------------------------------------------------
@is_constituent = ( db, glyph, handler ) ->
  #=========================================================================================================
  step ( resume ) =>*
    glyph_id    = MJK.get_node_id db, 'glyph', glyph
    true_id     = MJK.get_node_id db, 'flag',  true
    glyph_entry = yield MJK.get db, glyph_id, null, resume
    #.......................................................................................................
    return handler new Error "unable to find glyph #{rpr glyph} in database" unless glyph_entry?
    #.......................................................................................................
    query       = """isa:"edge" AND from:"#{glyph_id}" AND key:"shape/is-constituent" """
    response    = yield MJK.search db, query, resume
    results     = response[ 'results' ]
    #.......................................................................................................
    return handler null, false if results.length is 0
    handler null, ( results[ 0 ][ 'to' ] is true_id )
  #=========================================================================================================
  return null


#-----------------------------------------------------------------------------------------------------------
@main = ( db ) ->
  step ( resume ) =>*
    glyphs = CHR.chrs_from_text '掀'
    # """國國或北京，簡稱京，係中華人民共和國嘅首都，有過千年歷史1153年，金朝設中都，是為北京建
    # """
    # 都之始，2013年是北京建都860周年[3]。金中都人口超過一百萬。金中都為元、明、清三代的北京城的建設奠定了基礎。
    # 北京位於華北平原的西北邊緣，背靠燕山，有永定河流經老城西南，毗鄰天津市、河北省，是一座有三千餘年建城歷史、
    # 八百六十餘年建都史的歷史文化名城，歷史上有金、元、明、清、中華民國（北洋政府時期）等五個朝代在此定都，以及數個政權建政於此，
    # 薈萃了自元明清以來的中華文化，擁有眾多歷史名勝古迹和人文景觀。"""
    for glyph in glyphs
      yield @analyze_formula db, glyph, resume
    # log TRM.grey db
    MJK.CACHE.log_report db

# #-----------------------------------------------------------------------------------------------------------
# @test_formula_analysis = ->
#   db    = MJK.new_db()
#   glyph = '燕'
#   #=========================================================================================================
#   step ( resume ) =>*

#-----------------------------------------------------------------------------------------------------------
@test_constituents = ( test ) ->
  db      = MJK.new_db()
  glyphs  = CHR.chrs_from_text """充皃靣兒面𢀖半凸凹石穴貝贝虍"""
  #=========================================================================================================
  step ( resume ) =>*
    for glyph in glyphs
      bool = yield @is_constituent db, glyph, resume
      log ( TRM.pink glyph ), ( if bool then TRM.green 'constituent' else TRM.red 'not a constituent' )
    #.......................................................................................................
    test.done()
  #=========================================================================================================
  return null

#-----------------------------------------------------------------------------------------------------------
@test_character_infos = ( test ) ->
  write_table = require 'yatf'
  #.........................................................................................................
  db      = MJK.new_db()
  glyphs  = CHR.chrs_from_text """充"""
  glyphs  = CHR.chrs_from_text """充皃靣兒面𢀖半凸凹石穴貝贝虍"""
  glyphs  = CHR.chrs_from_text """國"""
  #.........................................................................................................
  options =
    'result-count':   50
  #=========================================================================================================
  step ( resume ) =>*
    for glyph in glyphs
      log()
      sid           = MJK.get_node_id db, 'glyph', glyph
      subject       = yield MJK.get db, sid, resume
      #.....................................................................................................
      query         = """isa:"edge" AND from:"#{sid}" """
      response      = yield MJK.search db, query, options, resume
      predicates    = response[ 'results' ]
      table_headers = [ 'sk', 'subject', 'predicate', 'idx', 'ok', 'object', ]
      rows          = []
      for predicate in predicates
        # log predicate
        idx           = predicate[ 'idx'  ]
        oid           = predicate[ 'to'   ]
        object        = yield MJK.get db, oid, resume
        # @_log_phrase db, subject, predicate, object
        rows.push @_get_phrase db, subject, predicate, idx, object
      #.....................................................................................................
      query         = """isa:"edge" AND to:"#{sid}" """
      response      = yield MJK.search db, query, options, resume
      predicates    = response[ 'results' ]
      for predicate in predicates
        idx           = predicate[ 'idx'  ]
        oid           = predicate[ 'from' ]
        object        = yield MJK.get db, oid, resume
        # @_log_phrase db, object, predicate, subject
        rows.push @_get_phrase db, object, predicate, idx, subject
      #.....................................................................................................
      log()
      write_table table_headers, rows, underlineHeaders: yes
      log()
    #.......................................................................................................
    test.done()
  #=========================================================================================================
  return null

#-----------------------------------------------------------------------------------------------------------
@_get_phrase = ( db, subject, predicate, idx, object ) ->
  sk  = subject[ 'key' ]
  sv  = subject[ 'value' ]
  sv  = rpr sv unless TYPES.isa_text sv
  sv  = "#{CHR.as_fncr sv, input: 'xncr'} #{sv}" if sk is 'glyph'
  pk  = predicate[ 'key' ]
  ok  = object[ 'key' ]
  ov  = object[ 'value' ]
  ov  = "#{CHR.as_fncr ov, input: 'xncr'} #{ov}" if ok is 'glyph'
  ov  = rpr ov unless TYPES.isa_text ov
  #.........................................................................................................
  sk  = TRM.grey    sk
  sv  = TRM.red     sv
  pk  = TRM.orange  pk
  idx = TRM.grey    "#{idx}"
  ok  = TRM.grey    ok
  ov  = TRM.green   ov
  # #.........................................................................................................
  # log ( TRM.grey sk ), ( TRM.red sv ), ( TRM.grey '--' ), ( TRM.orange pk ), ( TRM.grey '->' ), ( TRM.grey ok ), ( TRM.green ov )
  return [ sk, sv, pk, idx, ok, ov, ]

#-----------------------------------------------------------------------------------------------------------
TEXT_flush_left = ( me, width ) ->
  return me if me.length >= width
  return me + ( new Array width - me.length ).join ' '

# 國  冂口
# 國  冂或
# 國  口或
# 國  口國
# 國  弋或
# 國  弋戈
# 國  丿或
# 國  丿戈
# 國  丨口
# 國  丨或
# 國  丨冂
# 國  𠃌口
# 國  𠃌或
# 國  𠃌冂
# 國  七或
# 國  七戈
# 國  七弋
# 國  丶或
# 國  丶戈
# 國  丶弋
# 國  乚或
# 國  乚戈
# 國  乚弋
# 國  乚七
# 國  一口
# 國  一或
# 國  一戈
# 國  一弋
# 國  一七
# 國  戈或
# 國  或國


# 木  一十
# 木  丨十
# 木  丿人
# 木  ㇏人
# 木  十木
# 木  人木

############################################################################################################
test = done: ->

# do @main

# @query2 test
# db = MJK.new_db()
# log TRM.grey db
# @analyze_formula db, '國', ( error, results ) ->
#   throw error if error?
#   log TRM.orange results

# @query_test_entries db, ( error, results ) ->
#   throw error if error?
#   log TRM.orange results

# @main db

# @get_all db

# @test_constituents test
@test_character_infos test



