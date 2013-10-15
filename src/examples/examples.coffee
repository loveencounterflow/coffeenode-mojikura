
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
MOJIKURA                  = require 'coffeenode-mojikura'
log                       = TRM.log.bind TRM
rpr                       = TRM.rpr.bind TRM
echo                      = TRM.echo.bind TRM
#...........................................................................................................
suspend                   = require 'coffeenode-suspend'
step                      = suspend.step
collect                   = suspend.collect
immediately               = setImmediate
eventually                = process.nextTick




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

search_ics = ( db, glyph, handler ) ->
  step ( resume ) ->*
    options =
      'result-count':   500
    ### TAINT should be using join ###
    query = [
      glyph
      { 'out:has/shape/breakdown/formula': wild '*' } ]
    entries   = yield MOJIKURA.search db, query, options, resume
    log TRM.gold '©5x2', entries

#-----------------------------------------------------------------------------------------------------------
search_component = ( db, component, exceptions, handler ) ->
  QUERY = MOJIKURA.QUERY
  any   = QUERY.any
  all   = QUERY.all
  q     = QUERY.term
  rng   = QUERY.range
  wild  = QUERY.wildcard
  regex = QUERY.regex
  #.........................................................................................................
  step ( resume ) ->*
    options =
      'result-count':   1000
      'sort':           'k asc, v asc'
    # query = id: 'glyph:中'
    #.......................................................................................................
    query = [
      { component:  component, }
      { usagecode:  wild '*' }
      ]
    #.......................................................................................................
    if exceptions? and exceptions.length isnt 0
      matcher = ///#{component}:[^#{exceptions}]///
      query.push { 'carrier': matcher, }
    #.......................................................................................................
    glyph_entries = yield MOJIKURA.search db, query, options, resume
    log TRM.blue "found #{glyph_entries.length} glyph_entries"
    #.......................................................................................................
    all_carriers  = {}
    glyphs        = []
    for glyph_entry in glyph_entries
      glyphs.push glyph_entry[ 'v' ]
      #.....................................................................................................
      carriers = glyph_entry[ 'carrier' ]
      if carriers?
        carriers_txt = []
        for carrier in carriers
          # if carrier is '田:軌'
          #   log TRM.pink '©9z4', glyph_entry
          if TEXT.starts_with carrier, component
            # carrier = carrier.replace /^.+:/, ''
            all_carriers[ carrier ] = 1
            carriers_txt.unshift  TRM.gold carrier
          # else
          #   carriers_txt.push     TRM.grey carrier
        carriers_txt  = carriers_txt.join ', '
      else
        carriers_txt  = './.'
      #.....................................................................................................
      # log ( TRM.steel glyph_entry[ 'v' ] ), carriers_txt
    #.......................................................................................................
    log ( TRM.steel glyph for glyph in glyphs ).join ' '
    matcher = ///^#{component}:///
    all_carriers  = ( carrier.replace matcher, '' for carrier of all_carriers )
    log ( TRM.gold carrier for carrier in all_carriers ).sort().join ' '
    echo all_carriers.sort().join ''
    handler null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
show_glyph_entry = ( glyph, handler ) ->
  db = MOJIKURA.new_db()
  step ( resume ) ->*
    #.......................................................................................................
    query   = glyph
    entries = yield MOJIKURA.search db, query, resume
    unless length = entries.length is 1
      return handler new Error "expected one result when searching for #{rpr glyph}, got #{length}"
    log TRM.indigo entries[ 0 ]
    #.......................................................................................................
    handler null if handler?
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
analyze_glyph = ( db, glyph, handler ) ->
  step ( resume ) ->*
    carriers = yield _analyze_glyph db, glyph, {}, {}, resume
    carriers = ( carrier for carrier of carriers ).sort()
    log ( TRM.gold carrier for carrier in carriers ).join ', '
    handler null, carriers
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
_analyze_glyph = ( db, glyph, seen_glyphs, carriers, handler ) ->
  return handler null, carriers if seen_glyphs[ glyph ]?
  seen_glyphs[ glyph ] = 1
  #.........................................................................................................
  step ( resume ) ->*
    #.......................................................................................................
    query   = glyph
    entries = yield MOJIKURA.search db, query, resume
    unless length = entries.length is 1
      return handler new Error "expected one result when searching for #{rpr glyph}, got #{length}"
    glyph_entry = entries[ 0 ]
    ics         = glyph_entry[ 'ic' ]
    components  = glyph_entry[ 'component' ]
    #.......................................................................................................
    if ics?
      local_carriers = {}
      for ic in ics
        carrier                   = ic.concat ':', glyph
        local_carriers[ carrier ] = 1
        carriers[ carrier ]       = 1
      carriers_txt    = TRM.grey ( key for key of local_carriers ).join ' '
      ics_txt         = TRM.lime ics.join ' '
    else
      ics_txt         = ''
      carriers_txt    = ''
    #.......................................................................................................
    if components?
      if ics?
        components      = ( component for component in components when ( ics.indexOf component ) is -1 )
      components_txt  = TRM.gold components.join ' '
    else
      components_txt  = ''
    #.......................................................................................................
    log TRM.steel glyph,
      TEXT.flush_left        ics_txt, 25, '\u3000'
      TEXT.flush_left components_txt, 25, '\u3000'
      carriers_txt
    if ics?
      for ic in ics
        # log TRM.red ic, ics
        yield _analyze_glyph db, ic, seen_glyphs, carriers, resume
    #.......................................................................................................
    handler null, carriers if handler?
  #.........................................................................................................
  return null

# /人:[^飠亽亼今厥欮金欠木谷大奇夹夫走灰火龰魏委禾犬]/
# search_component '爪' #, '瓜'
# search_component '人' #, '瓜'
# search_component '大' #, '瓜'
# search_component db, '巾'

#-----------------------------------------------------------------------------------------------------------
show_codepoint_statistics = ->
  db    = MOJIKURA.new_db()
  QUERY = MOJIKURA.QUERY
  any   = QUERY.any
  all   = QUERY.all
  q     = QUERY.term
  rng   = QUERY.range
  wild  = QUERY.wildcard
  regex = QUERY.regex
  TIMER = require 'coffeenode-timer'
  step ( resume ) ->*
    # yield analyze_glyph db, '𢃇', resume
    # yield show_glyph_entry db, '團', resume
    # for cid in [ 0x9fbb .. 0x9fcc ]
    #   glyph = CHR.as_chr cid
    #   log()
    #   log TRM.gold rpr glyph
    #   yield show_glyph_entry db, glyph , resume
    # yield show_glyph_entry db, '𢃇', resume
    '樂'
    # yield search_component db, '人', '大天夫夾幾木欠火睿禽禾臾木欠火禾亥以内及谷金食齿龰𠀔𠔿𡗗', resume
    # yield search_component db, '亻', '千彳', resume
    # yield search_component db, '日', '田甴白百禺里曱曲𠁣𠃛', resume
    # yield search_component db, '彡', '', resume
    UCD = require 'jizura-ucd'
    #.........................................................................................................
    cid_ranges_by_scriptname  = yield UCD.read_cid_ranges_by_scriptname resume
    cjk_cid_ranges            = cid_ranges_by_scriptname[ 'Han' ]
    target_count_by_cid       = {}
    jzr_cjk_count             = 0
    cjk_cids                  = {}
    #.......................................................................................................
    for range in cjk_cid_ranges
      [ min_cid, max_cid ] = range
      for cid in [ min_cid .. max_cid ]
        cjk_cids[ cid ] = 0
    # ### adding CIDs of single strokes: ###
    # for cid in [ 0x31c0 .. 0x31e3 ]
    #   cjk_cids[ cid ] = 0
    #.......................................................................................................
    illegal_rsgs =
      # 'u':             1
      'u-bopo':         1
      'u-boxdr':        1
      # 'u-cjk':          1
      'u-cjk-cmpf':     1
      # 'u-cjk-cmpi1':    1
      # 'u-cjk-cmpi2':    1
      'u-cjk-idc':      1
      'u-cjk-kata':     1
      # 'u-cjk-rad1':     1
      # 'u-cjk-rad2':     1
      # 'u-cjk-strk':     1
      # 'u-cjk-sym':      1
      # 'u-cjk-xa':       1
      # 'u-cjk-xb':       1
      # 'u-cjk-xc':       1
      # 'u-cjk-xd':       1
      'u-geoms':        1
      'u-halfull':      1
      'u-latn':         1
      'u-latn-1':       1
      'u-punct':        1
    #.......................................................................................................
    value_count       = 0
    counts            =
      'Unicode':          0
      'Jizura':           0
      'other':            0
    duplicate_counts  =
      'Unicode':          0
      'Jizura':           0
      'other':            0
    query             = k: wild '*'
    page_size         = 5000
    page_count        = 0
    first_idx         = 0
    options           =
      'result-count':   page_size
      'first-idx':      first_idx
      # 'sort':           'k asc, v asc'
    #.......................................................................................................
    loop
      # TIMER.start "retrieve #{page_size} entries"
      entries     = yield MOJIKURA.search db, query, options, resume
      # TIMER.stop "retrieve #{page_size} entries"
      if entries.length is 0
        # TIMER.log_report()
        total_count           = 0
        total_duplicate_count = 0
        total_resulting_count = 0
        #...................................................................................................
        log()
        log TRM.blue ( TEXT.flush_left        'Character Set', 15 ),
                     ( TEXT.flush_right    'codepoints in DB', 22 ),
                     ( TEXT.flush_right 'mapped to other CPs', 22 ),
                     ( TEXT.flush_right                 'sum', 22 )
        #...................................................................................................
        log TRM.gold '------------------------------------------------------------------------------------'
        for csg in ( csg for csg of counts ).sort()
          count                   = counts[           csg ]
          duplicate_count         = duplicate_counts[ csg ]
          resulting_count         = count - duplicate_count
          total_count            += count
          total_duplicate_count  += duplicate_count
          total_resulting_count  += resulting_count
          #.................................................................................................
          log TRM.blue ( TEXT.flush_left              csg, 15 ),
                       ( TEXT.flush_right           count, 22 ),
                       ( TEXT.flush_right duplicate_count, 22 ),
                       ( TEXT.flush_right resulting_count, 22 )
        #...................................................................................................
        log TRM.gold '------------------------------------------------------------------------------------'
        log TRM.blue ( TEXT.flush_left                 'sums', 15 ),
                     ( TEXT.flush_right           total_count, 22 ),
                     ( TEXT.flush_right total_duplicate_count, 22 ),
                     ( TEXT.flush_right total_resulting_count, 22 )
        #...................................................................................................
        log()
        jzr_cjk_resulting_count   = 0
        jzr_cjk_resulting_count  += counts[ 'Unicode' ]
        jzr_cjk_resulting_count  += counts[ 'Jizura' ]
        jzr_cjk_resulting_count  -= duplicate_counts[ 'Unicode']
        jzr_cjk_resulting_count  -= duplicate_counts[ 'Jizura']
        log TRM.blue "There are currently #{( Object.keys cjk_cids ).length} codepoints in Unicode"
        log TRM.blue "with the property 'Script: Han';"
        log TRM.blue "including duplicates, we recognize #{jzr_cjk_count} codepoints as CJK Ideographs"
        log TRM.blue "in Jizura, and #{jzr_cjk_resulting_count} codepoints excluding duplicates."
        log()
        #...................................................................................................
        unicode_count   = counts[ 'Unicode' ] - duplicate_counts[ 'Unicode' ]
        jzr_count       = counts[ 'Jizura'  ] - duplicate_counts[ 'Jizura'  ]
        ujzr_count      = unicode_count + jzr_count
        dpg             = ( value_count / ujzr_count ).toFixed 2
        log TRM.green "a total of #{value_count} datapoints for Unicode and Jizura are currently registered"
        log TRM.green "(ignoring glyph mapping data)"
        log TRM.green "which is an average of #{dpg} datapoints per effective glyph"
        #...................................................................................................
        for cid_txt, count of target_count_by_cid
          continue if count < 2
          cid   = parseInt cid_txt, 10
          info  = CHR.analyze CHR.as_chr cid
          log '©23e', TRM.steel count, info[ 'fncr' ], info[ 'chr' ]
        break
      #.....................................................................................................
      log TRM.blue "page #{page_count}"
      #.....................................................................................................
      for entry in entries
        glyph             = entry[ 'v' ]
        target_glyph      = entry[ 'mapped-to/global' ]
        info              = CHR.analyze glyph, input: 'xncr'
        csg               = info[ 'csg' ]
        rsg               = info[ 'rsg' ]
        cid               = info[ 'cid' ]
        #...................................................................................................
        if csg is 'u' or csg is 'jzr'
          jzr_cjk_count += 1
          for name, value of entry
            continue if name is 'id'
            continue if name is '_version_'
            if TEXT.starts_with name, 'mapped-to'
              if name is 'mapped-to/global'
                target_cid = CHR.as_cid value, input: 'xncr'
                target_count_by_cid[ target_cid ] = ( target_count_by_cid[ target_cid ] ? 0 ) + 1
              continue
            value_count += if TYPES.isa_list value then value.length else 1
        #...................................................................................................
        if illegal_rsgs[ rsg ]?
          continue if rsg is 'u-latn-1' and glyph is '§'
          log ( TRM.lime rsg ), TRM.red JSON.stringify entry
        #...................................................................................................
        if csg is 'u'
          unless cjk_cids[ cid ]?
            continue if rsg is 'u-cjk-sym'
            continue if rsg is 'u-cjk-strk'
            log TRM.gold JSON.stringify info
        #...................................................................................................
        if      csg is 'u'    then  key = 'Unicode'
        else if csg is 'jzr'  then  key = 'Jizura'
        else                        key = 'other'
        counts[           key ] += 1
        duplicate_counts[ key ] += 1 if target_glyph?
      #.....................................................................................................
      first_idx  += page_size
      page_count += 1
      #.....................................................................................................
      options[ 'first-idx' ]  = first_idx
      page_count             += 1
  #.........................................................................................................
  return null


  # for range in cjk_cid_ranges
  #   [ min_cid, max_cid ] = range
  #   #.....................................................................................................
  #   for cid in [ min_cid ... max_cid ]
  #     glyph   = CHR.as_chr cid
  #     # log ( min_cid.toString 16 ), ( max_cid.toString 16 ) #, ( rpr scriptname )
  #     query   = glyph
  #     entries = yield MOJIKURA.search db, query, resume
  #     unless length = entries.length is 1
  #       return handler new Error "expected one result when searching for #{rpr glyph}, got #{length}"
  #     glyph_entry = entries[ 0 ]
  #     log TRM.indigo glyph, ( key for key of glyph_entry ).length

#-----------------------------------------------------------------------------------------------------------
show_glyphs_without_proper_formula = ->
  db    = MOJIKURA.new_db()
  QUERY = MOJIKURA.QUERY
  any   = QUERY.any
  all   = QUERY.all
  q     = QUERY.term
  rng   = QUERY.range
  wild  = QUERY.wildcard
  regex = QUERY.regex
  TIMER = require 'coffeenode-timer'
  #.........................................................................................................
  collector   = []
  counts      = {}
  query       = [ { formula: '〓' }, ] #v: /^[^&].*/ ]
  page_size   = 5000
  page_count  = 0
  first_idx   = 0
  options     =
    'result-count':   page_size
    'first-idx':      first_idx
    'sort':           'k asc, v asc'
  #.........................................................................................................
  step ( resume ) ->*
    #.......................................................................................................
    loop
      TIMER.start "retrieve #{page_size} entries"
      entries     = yield MOJIKURA.search db, query, options, resume
      for entry in entries
        glyph       = entry[ 'v' ]
        sub_query   = component: glyph, usagecode: wild '*'
        sub_entries = yield MOJIKURA.search db, sub_query, options, resume
        # log TRM.steel glyph, TRM.grey sub_entries.length
        collector.push [ glyph, sub_entries.length ]
      break
    #.......................................................................................................
    collector.sort ( a, b ) ->
      return +1 if a[ 1 ] > b[ 1 ]
      return -1 if a[ 1 ] < b[ 1 ]
      return 0
    total_count = 0
    for [ glyph, count ] in collector
      total_count += count
      log TRM.steel glyph, TRM.grey count
    log TRM.blue "#{collector.length} glyphs missing a formula"
    log TRM.blue "affecting #{total_count} glyphs in sample selection"
  #.........................................................................................................
  return null

f = ->
  db    = MOJIKURA.new_db()
  target_glyph  = '龜'
  target_fncr   = CHR.as_fncr target_glyph, input: 'xncr'
  step ( resume ) ->*
    entries = yield MOJIKURA.search db, { 'mapped-to/global': target_glyph, }, resume
    for entry in entries
      source_glyph  = entry[ 'v' ]
      source_fncr   = CHR.as_fncr source_glyph, input: 'xncr'
      log ( TRM.green target_fncr, target_glyph ), '<-', ( TRM.red source_fncr, source_glyph )
# f()


# show_glyphs_without_proper_formula()
# show_codepoint_statistics()

# /人:[^飠亽亼今厥欮金欠木谷大奇夹夫走灰火龰魏委禾犬]/
# search_component '爪' #, '瓜'
# search_component '人' #, '瓜'
# search_component '大' #, '瓜'
# search_component db, '巾'



#-----------------------------------------------------------------------------------------------------------
g = ( glyph, handler ) ->
  assert = require 'assert'
  equals = ( a, b ) ->
    try
      assert.deepEqual a, b
      return true
    catch error
      return false
  #.........................................................................................................
  # log TRM.pink glyph
  db              = MOJIKURA.new_db()
  guides_by_glyph = {}
  placeholder     = '\u3000'
  replacer        = '●'
  #.........................................................................................................
  step ( resume ) ->*
    #.......................................................................................................
    id              = "glyph:#{glyph}"
    #.......................................................................................................
    glyph_entry               = yield MOJIKURA.get db, id, resume
    return handler new Error "unable to find formula for glyph #{rpr glyph}" unless glyph_entry[ 'formula' ]
    formula                   = glyph_entry[ 'formula'   ][ 0 ]
    if glyph_entry[ 'guide' ]?
      leaders                   = glyph_entry[ 'guide'     ][ 0 .. 1 ]
      guides                    = glyph_entry[ 'guide'     ][ 2 ..   ]
    else
      leaders                   = [ replacer, replacer, ]
      guides                    = glyph_entry[ 'ic0'     ]
    guides_by_glyph[ glyph ]  = guides
    id                        = "formula:#{formula}"
    formula_entry             = yield MOJIKURA.get db, id, resume
    ics                       = formula_entry[ 'ic' ]
    #.......................................................................................................
    unless ics?
      ics                       = [ glyph, ]
      guides_by_glyph[ glyph ]  = ics
    #.......................................................................................................
    else
      for ic in ics
        id                    = "glyph:#{ic}"
        ic_entry              = yield MOJIKURA.get db, id, resume
        if ic_entry[ 'guide' ]?
          guides_by_glyph[ ic ] = ic_entry[ 'guide' ][ 2 .. ]
        else
          # log TRM.red ic_entry
          if ic_entry[ 'is-constituent' ]
            guides_by_glyph[ ic ] = [ ic, ]
          else
            guides_by_glyph[ ic ] = ic_entry[ 'ic0' ]
    #.......................................................................................................
    buffer          = []
    ic_idx          = 0
    ic              = ics[ ic_idx ]
    ic_guides       = guides_by_glyph[ ic ]
    components_line = []
    guides_line     = []
    for guide in guides
      buffer.push guide
      components_line.push guide
      if equals buffer, ic_guides
        # log ( TRM.gold ic ), ( TRM.green buffer.join ' ' )
        guides_line.push ic
        ic_idx         += 1
        ic              = ics[ ic_idx ]
        ic_guides       = guides_by_glyph[ ic ]
        buffer.length   = 0
      else
        guides_line.push placeholder
    #.......................................................................................................
    return handler null unless guides_line[ guides_line.length - 1 ] is placeholder
    #.......................................................................................................
    for line in [ leaders, components_line, guides_line ]
      for element, idx in line
        line[ idx ] = replacer if element[ 0 ] is '&'
    #.......................................................................................................
    # log TRM.steel glyph #, '>', ( ics.join ' ' ), '>', ( guides.join ' ' )
    guides_txt      = TRM.green      guides_line.join ' '
    components_txt  = TRM.gold   components_line.join ' '
    leaders_txt     = TRM.pink           leaders.join ' '
    spacer          = '\u3000 \u3000'
    log()
    log leaders_txt, components_txt, TRM.pink glyph
    log spacer,          guides_txt
    guides_txt      =     guides_line.join ' '
    components_txt  = components_line.join ' '
    leaders_txt     =         leaders.join ' '
    echo()
    echo leaders_txt, components_txt, glyph
    echo spacer,          guides_txt
    #.......................................................................................................
    handler null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
# step ( resume ) ->*
#   db          = MOJIKURA.new_db()
#   query       = [ k: ( wild '*' ), 'dictionary-idx': ( wild '*' ), ]
#   options     =
#     'result-count':   1000
#     'first-idx':      0
#     # 'sort':           'k asc, v asc'
#   entries     = yield MOJIKURA.search db, query, options, resume
#   # for glyph in CHR.chrs_from_text '掀勰灑孬攬遊裹國偃偄偅偆假偈偉偊偋偌偍偎偏'
#   for glyph in CHR.chrs_from_text '隋'
#   # for entry in entries
#     # glyph = entry[ 'v' ]
#     yield g glyph, resume
#     show_glyph_entry '&jzr#xe16b;'


# 丶 ● 忄 巛 ● 乂 惱
# 　 　 忄

# 丶 ● 忄 十 戈 非 一 懴
# 　 　 忄

# 丶 ● 忄 卄 罒 目 懵
# 　 　 忄

# simplify / add new function DSB.read_immediate_constituents_by_chr
# so that a single list is recoreded for each character, combining the results
# of all formulas

# populate.add_components_and_consequential_pairs
# (or an appropriate method in DSB)
# should have a recursive function to compute consequential pairs
# (or use shared lists technique)














