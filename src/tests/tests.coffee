

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
eventually                = process.nextTick
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


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@log_report = ( db, st, sk, sv, handler ) ->
  #.........................................................................................................
  step ( resume ) =>*
    Z = yield @_report db, st, sk, sv, yes, resume
    # log Z
    handler null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@report = ( db, st, sk, sv, handler ) ->
  return @_report db, st, sk, sv, no, handler

#-----------------------------------------------------------------------------------------------------------
@_report = ( db, st, sk, sv, is_live, handler ) ->
  seen_srs  = {}
  level     = 0
  #.........................................................................................................
  if is_live
    Z         = null
    pen       = ( P... ) -> log P...
  #.........................................................................................................
  else
    Z         = []
    pen       = ( P... ) -> Z.push TRM.pen P...
  #.........................................................................................................
  options =
    'result-count':   500
    'sort':           'sk asc, pk asc, pi asc'
  #.........................................................................................................
  step ( resume ) =>*
    pen()
    yield @_inner_report db, st, sk, sv, options, seen_srs, level, pen, resume
    handler null, if is_live then null else Z.join ''
  #.........................................................................................................
  return null

# #-----------------------------------------------------------------------------------------------------------
# sort_entries = ( entries ) ->
#   entries.sort ( a, b ) ->
#     return +1 if a[ 'ok' ] > b[ 'ok' ]
#     return -1 if a[ 'ok' ] < b[ 'ok' ]
#     return +1 if a[ 'pi' ] > b[ 'pi' ]
#     return -1 if a[ 'pi' ] < b[ 'pi' ]
#     return 0

#-----------------------------------------------------------------------------------------------------------
@_inner_report = ( db, st, sk, sv, options, seen_srs, level, pen, handler ) ->
  # log TRM.steel '©4d3', st, sk, sv
  #.........................................................................................................
  step ( resume ) =>*
    # sid           = ( MJK.new_entry db, st, sk, sv )[ 'id' ]
    sv_name       = MJK.sv_name_from_st db, st
    sk_txt        = if sk? then MJK.quote sk else '*'
    sv_txt        = if sv? then MJK.quote sv.toString() else '*'
    #.....................................................................................................
    query         = """sk:#{sk_txt} AND #{sv_name}:#{sv_txt}"""
    response      = yield MJK.search db, query, options, resume
    entries       = response[ 'results' ]
    # log TRM.pink entries
    #.....................................................................................................
    return handler null if entries.length is 0
    # pen TRM.grey MJK.rpr_of_entry s, yes
    # sort_entries entries
    indentation = TEXT.repeat '  ', level
    pen indentation, ( TRM.grey sk ), ( TRM.green sv )
    indentation = TEXT.repeat '  ', level + 1 #!!!!!!!!!!!!!!!!!!!!!!!!!!
    #.....................................................................................................
    for entry in entries
      # log '©2w0', entry
      #.....................................................................................................
      if entry[ 'ot' ] is 'm'
        # pen TRM.grey MJK.rpr_of_entry entry, yes
        category_mark = TRM.grey '↳'
        oid           = entry[ 'ov.m' ]
        sub_query     = """id:"#{oid}" """
        sub_response  = yield MJK.search db, sub_query, options, resume
        sub_entries   = sub_response[ 'results' ]
        for sub_entry in sub_entries
          sub_st        = sub_entry[ 'st' ]
          sub_sk        = sub_entry[ 'sk' ]
          sub_sv        = MJK.get_sv db, sub_entry
          sub_sr        = MJK._rpr_of_subject sub_st, sub_sk, sub_sv
          # pen indentation, TRM.grey MJK.rpr_of_entry sub_entry, yes
          # log '©5t2', indentation, ( TRM.orange entry[ 'pk' ] ), ( TRM.white '->' ), ( TRM.grey sub_sk ), ( TRM.green sub_sv )
          if is_seen = seen_srs[ sub_sr ]?
            continuation_mark = TRM.pink '...'
          else
            continuation_mark = ''
          pen indentation,
            category_mark
            ( TRM.grey sk )
            ( TRM.green sv )
            ( TRM.white '▶' )
            ( TRM.orange entry[ 'pk' ] )
            ( TRM.orange entry[ 'pi' ] )
            ( TRM.white '▶' )
            ( TRM.grey sub_sk )
            ( TRM.green sub_sv )
            continuation_mark
          #.................................................................................................
          continue if is_seen
          #.................................................................................................
          seen_srs[ sub_sr ] = 1
          yield @_inner_report db, sub_st, sub_sk, sub_sv, options, seen_srs, level + 1, pen, resume
      #.....................................................................................................
      else
        category_mark     = TRM.grey '↦'
        continuation_mark = TRM.red '.'
        ok                = entry[ 'ok' ]
        ot                = entry[ 'ot' ]
        ov                = MJK.get_ov db, entry
        pk                = entry[ 'pk' ]
        pi                = entry[ 'pi' ]
        pen level, indentation,
          category_mark
          ( TRM.grey sk )
          ( TRM.green sv )
          unless ov? then '' else ( TRM.white '▶' )
          unless ov? then '' else ( TRM.orange pk )
          unless ov? then '' else ( TRM.orange pi )
          unless ov? then '' else ( TRM.white '▶' )
          unless ov? then '' else ( TRM.grey ok )
          unless ov? then '' else ( TRM.green ov )
          continuation_mark
        if  ( ( level == 0 or level == 2 ) and pk is 'has/shape/breakdown/formula' ) or
            (   level == 1                 and pk is 'has/shape/breakdown/ic'      )
          yield @_inner_report db, ot, ok, ov, options, seen_srs, level + 1, pen, resume
      #.....................................................................................................
      entry_id      = entry[ 'id' ]
      # meta_query    = """sv.m:"#{entry_id}" """
      # meta_response = yield MJK.search db, query, options, resume
      # meta_entries  = response[ 'results' ]
      # log meta_entries
      # yield @_inner_report db, 'm', null, entry_id, options, seen_srs, level + 1, pen, resume
    #.....................................................................................................
    handler null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
MJK.resolve_subject   = ( me, entry, handler ) -> return @_resolve  me, entry, 's', handler
MJK.resolve_object    = ( me, entry, handler ) -> return @_resolve  me, entry, 'o', handler
MJK.describe_subject  = ( me, entry, handler ) -> return @_describe me, entry, 's', handler
MJK.describe_object   = ( me, entry, handler ) -> return @_describe me, entry, 'o', handler

#-----------------------------------------------------------------------------------------------------------
MJK._resolve = ( me, entry, sigil, handler ) ->
  t_name = sigil.concat 't'
  v_name = sigil.concat 'v.m'
  return @_resolve_inner me, entry, t_name, v_name, handler

#-----------------------------------------------------------------------------------------------------------
MJK._describe = ( me, entry, sigil, handler ) ->
  v_name = sigil.concat 'v.m'
  return @_describe_inner me, entry, v_name, handler

#-----------------------------------------------------------------------------------------------------------
MJK._resolve_inner = ( me, entry, t_name, v_name, handler ) ->
  #.........................................................................................................
  unless entry[ t_name ] is 'm'
    eventually -> handler null, entry
    return null
  #.........................................................................................................
  referred_id = entry[ v_name ]
  query       = """id:#{@quote referred_id}"""
  @search me, query, { 'result-count': 1 }, ( error, response ) =>
    return handler error if error?
    #.......................................................................................................
    # log TRM.grey '©4r1', response
    entries = response[ 'results' ]
    handler new Error "unable to find entry with ID #{referred_id}" if entries.length is 0
    # @_resolve_inner me, entries[ 0 ], t_name, v_name, handler
    # log '©8u6', entry, t_name, v_name, handler
    handler null, entries[ 0 ]
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
MJK._describe_inner = ( me, entry, v_name, handler ) ->
  id          = entry[ 'id' ]
  query       = """#{v_name}:#{@quote id}"""
  @search me, query, { 'result-count': 1e6 }, ( error, response ) =>
    return handler error if error?
    #.......................................................................................................
    # log TRM.grey '©4r1', response
    entries = response[ 'results' ]
    # @_describe_inner me, entries[ 0 ], v_name, handler
    handler null, entries
  #.........................................................................................................
  return null

# {!join from=sv to=sv} pk:"has/shape/breakdown/consequential-pair" AND ov:/口\<[^中]/



############################################################################################################
test = done: ->

#-----------------------------------------------------------------------------------------------------------
@demo = ->
  db = MJK.new_db()
  # glyph = '衷'
  # glyph = '木'
  step ( resume ) =>*
    # for glyph in '頑孬耍耐靦' # "一亓元頑顽鼋黿远弐武" #[ 0 ]
    # for glyph in '靦面見國裹醪近'
    # for glyph in '靦'
    for glyph in '醪'
      yield @log_report db, null, 'glyph', glyph, resume
    log TRM.blue 'ok'

#-----------------------------------------------------------------------------------------------------------
MJK.extract = ( me, entry, handler ) ->
  return @_extract me, entry, [], null, handler

#-----------------------------------------------------------------------------------------------------------
MJK._extract = ( me, entry, Z, sigil, handler ) ->
  sv  = @get_sv me, entry
  ov  = @get_ov me, entry
  if sigil?
    switch sigil
      when 's'
        null
      when 'o'
        null
      else return handler new Error "expected `s` or `o` as sigil, got #{rpr sigil}"
  else
    Z.push [ sv, entry[ 'pk' ], ov ]
  handler null, Z

#-----------------------------------------------------------------------------------------------------------
MJK.tuple_from_entry = ( me, entry, handler ) ->
  step ( resume ) =>*
    st  = entry[ 'st' ]
    sk  = entry[ 'sk' ]
    sv  = @get_sv me, entry
    pk  = entry[ 'pk' ]
    pi  = entry[ 'pi' ]
    ot  = entry[ 'ot' ]
    ok  = entry[ 'ok' ]
    ov  = @get_ov me, entry
    Z   = [ [ sk, sv, ], [ pk, pi, ], [ ok, ov, ],  ]
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


#-----------------------------------------------------------------------------------------------------------
@test_resolve_subject = ->
  step ( resume ) =>*
    db = MJK.new_db()
    entry = MJK.new_entry db, 'm', 'entity', 'c027f683e3ed', 'has/shape/breakdown/component', 5, 'm', 'entity', '65a64da5500b'
    #  "id":"b2bfa03fc57e"
    # log TRM.pink entry
    # log TRM.gold {"id":"b2bfa03fc57e","sk":"entity","st":"m","sv.m":"c027f683e3ed","pk":"has/shape/breakdown/component","pi":5,"ok":"entity","ot":"m","ov.m":"65a64da5500b"}
    log TRM.gold '——————————————————————————————————————————————————————————————————————————'
    log TRM.gold "original phrase:"
    log TRM.grey MJK.rpr_of_entry entry, yes
    entry_tuple = yield MJK.tuple_from_entry db, entry, resume
    log TRM.pink entry_tuple
    # subject = yield MJK.resolve_subject db, entry, resume
    # object  = yield MJK.resolve_object db, entry, resume
    s_descriptors = yield MJK.describe_subject db, entry, resume
    # log TRM.gold "subject:"
    # log TRM.steel MJK.rpr_of_entry subject, yes
    log TRM.gold "subject descriptors:"
    [ s, p, o, ]  = entry_tuple
    collector     = []
    target        = [ 'relation', [ s, p, o, ], [ 'because-of', null, ], [ 'entities', collector, ], ]
    for descriptor in s_descriptors
      # descriptor = yield
      log TRM.grey MJK.rpr_of_entry descriptor, yes
      descriptor_tuple = yield MJK.tuple_from_entry db, descriptor, resume
      log TRM.pink descriptor_tuple
      [ s, p, o, ]  = descriptor_tuple
      # log TRM.orange s
      [ pk, pi, ]   = p
      unless pk is 'because-of'
        log TRM.red "skipping meta-relationship #{rpr pk}"
        continue
      # log TRM.orange o
      [ ok, ov, ]   = o
      collector.push o
      #.....................................................................................................
      # descriptor_s  = yield MJK.resolve_subject db, descriptor,   resume
      # s_subject     = yield MJK.resolve_subject db, descriptor_s, resume
      # s_object      = yield MJK.resolve_object  db, descriptor_s, resume
      # log TRM.grey  's: -->', MJK.rpr_of_entry descriptor_s, yes
      # log TRM.steel 's: -->', ( MJK.get_sv db, s_subject ), descriptor_s[ 'pk' ], ( MJK.get_sv db, s_object )
      #.....................................................................................................
      # descriptor_o  = yield MJK.resolve_object db, descriptor, resume
      # o_subject     = yield MJK.resolve_subject db, descriptor_o, resume
      # o_object      = yield MJK.resolve_object  db, descriptor_o, resume
      # log TRM.grey  'o: -->', MJK.rpr_of_entry descriptor_o, yes
      # log TRM.steel 'o: -->', ( MJK.get_sv db, o_subject ), descriptor_o[ 'pk' ], ( MJK.get_sv db, o_object )
    # log TRM.gold "object:"
    # log TRM.steel MJK.rpr_of_entry object, yes
    # o_descriptors = yield MJK.describe_object db, entry, resume
    # log TRM.gold "object descriptors:"
    # for descriptor in o_descriptors
    #   # descriptor = yield
    #   log TRM.steel MJK.rpr_of_entry descriptor, yes
    log TRM.lime target
    log()

# do @test_resolve_subject



do @demo







