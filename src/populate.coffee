


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
POSTER                    = require './POSTER'
log                       = TRM.log.bind TRM
rpr                       = TRM.rpr.bind TRM
echo                      = TRM.echo.bind TRM
#...........................................................................................................
suspend                   = require 'coffeenode-suspend'
step                      = suspend.step
after                     = suspend.after
collect                   = suspend.collect
immediately               = setImmediate
eventually                = process.nextTick
#...........................................................................................................
log_file_route            = njs_path.join __dirname, '../data/log.txt'
#...........................................................................................................
DATASOURCES               = require '/Users/flow/JIZURA/flow/library/DATASOURCES'
DSB                       = DATASOURCES.SHAPE.BREAKDOWN
DSS                       = DATASOURCES.SHAPE.STROKEORDER
DSG                       = DATASOURCES.SHAPE.GUIDES
DSI                       = DATASOURCES.SHAPE.IDENTITY
### TAINT: module should migrate to datasources ###
read_dictionary_data      = require '/Users/flow/JIZURA/flow/dictionary/read-dictionary-data.cmatic'




# #===========================================================================================================
# # CACHES
# #-----------------------------------------------------------------------------------------------------------
# @_cache = {}

# #-----------------------------------------------------------------------------------------------------------
# @_fetch_id = ( db, st, sk, sv, handler ) ->
#   target  = @_cache[ sk ]?= {}
#   Z       = target[ sv ]
#   if Z? then return immediately -> handler null, Z
#   #.........................................................................................................
#   @new_entry db, st, sk, sv, ( error, entry ) ->
#     return handler error if error?
#     Z = entry[ 'id' ]
#     target[ sv ] = Z
#     handler null, Z
#   #.........................................................................................................
#   return null

#===========================================================================================================
# OBJECT CREATION
#-----------------------------------------------------------------------------------------------------------
@new_entry = ( db, P..., handler ) ->
  Z = MOJIKURA.new_entry db, P...
  POSTER.add_entry db, Z, ( error, result ) ->
    return handler error, Z


#===========================================================================================================
# TEST ENTRIES
#-----------------------------------------------------------------------------------------------------------
@add_test_entries = ( db, handler ) ->
  # log '©0u2'
  #.........................................................................................................
  step ( resume ) =>*
    entry = yield @new_entry db, null,  'test/text',      'just a text', resume
    entry = yield @new_entry db, 'b',   'test/boolean',   yes, resume
    entry = yield @new_entry db, 'b',   'test/boolean',   no, resume
    for n in [ 1024 ... 1050 ]
      entry = yield @new_entry db, 'i',   'test/number',    n, resume
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null


#===========================================================================================================
# DATA COLLECTING
#-----------------------------------------------------------------------------------------------------------
@add_strokeorders = ( db, handler ) ->
  #.........................................................................................................
  step ( resume ) =>*
    strokeorders_by_glyph = yield DSS.read_strokeorders_by_chr 'global', resume
    local_entry_count     = 0
    #.......................................................................................................
    for glyph, strokeorders of strokeorders_by_glyph
      local_entry_count += 1
      break if local_entry_count > db[ 'dev-max-entry-count' ]
      #.....................................................................................................
      for strokeorder, idx in strokeorders
        #...................................................................................................
        yield @new_entry db,
          null, 'glyph', glyph
          'has/shape/strokeorder/zhaziwubifa', idx
          null, 'shape/strokeorder/zhaziwubifa', strokeorder
          resume
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@add_formulas = ( db, handler ) ->
  #.........................................................................................................
  step ( resume ) =>*
    formulas_by_glyph           = yield DSB.read_formulas_by_chr 'global', resume
    corrected_formulas_by_glyph = yield DSB.read_corrected_formulas_by_chr 'global', resume
    local_entry_count           = 0
    #.......................................................................................................
    for glyph, formulas of formulas_by_glyph
      local_entry_count += 1
      break if local_entry_count > db[ 'dev-max-entry-count' ]
      #.....................................................................................................
      seen_formulas = {}
      #.....................................................................................................
      for formula, idx in formulas
        seen_formulas[ formula ] = 1
        #...................................................................................................
        yield @new_entry db,
          null, 'glyph', glyph
          'has/shape/breakdown/formula', idx
          null, 'shape/breakdown/formula', formula
          resume
      #.....................................................................................................
      for formula, idx in corrected_formulas_by_glyph[ glyph ]
        continue if seen_formulas[ formula ]
        #...................................................................................................
        yield @new_entry db,
          null, 'glyph', glyph
          'has/shape/breakdown/formula/corrected', idx
          null, 'shape/breakdown/formula/corrected', formula
          resume
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@add_immediate_constituents = ( db, handler ) ->
  #.........................................................................................................
  step ( resume ) =>*
    # ics_by_glyph      = yield DSB.read_preferred_immediate_constituents_by_chr  'global', resume
    formulas_by_glyph = yield DSB.read_formulas_by_chr 'global', resume
    ic_lists_by_glyph = yield DSB.read_immediate_constituents_by_chr  'global', resume
    local_entry_count = 0
    # log ics_by_glyph[ '意']
    # process.exit()
    #.......................................................................................................
    for glyph, ic_lists of ic_lists_by_glyph
      for ics, ic_list_idx in ic_lists
        local_entry_count += 1
        break if local_entry_count > db[ 'dev-max-entry-count' ]
        formula     = formulas_by_glyph[ glyph ][ ic_list_idx ]
        unless formula?
          log TRM.red '©5x2', "unable to find formula #{ic_list_idx}: #{glyph} #{rpr formulas_by_glyph[ glyph ]}"
          continue
        #...................................................................................................
        for ic, idx in ics
          yield @new_entry db,
            null, 'shape/breakdown/formula', formula
            'has/shape/breakdown/ic', idx
            null, 'glyph', ic
            resume
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@add_variants_and_usagecodes = ( db, handler ) ->
  #.........................................................................................................
  step ( resume ) =>*
    variants_and_usage_by_glyph = yield DATASOURCES.VARIANTUSAGE.read_variants_and_usage_by_chr     resume
    #.......................................................................................................
    [ variants_by_glyph
      usagecode_by_glyph ]      = variants_and_usage_by_glyph
    #.......................................................................................................
    variants_by_glyph           = variants_by_glyph[ 'elements' ]
    local_entry_count           = 0
    seen_ptag_warnings          = {}
    #.......................................................................................................
    ignore_ptag = ( glyph ) ->
      return glyph unless ( glyph.match /p$/ )?
      message = "©5r2 silently ignoring 'p' tag of variant #{glyph}"
      log TRM.red message unless seen_ptag_warnings[ message ]?
      seen_ptag_warnings[ message ] = 1
      return glyph.replace /p$/, ''
    #.......................................................................................................
    for glyph, variants of variants_by_glyph
      local_entry_count += 1
      break if local_entry_count > db[ 'dev-max-entry-count' ]
      #.....................................................................................................
      glyph       = ignore_ptag glyph
      #.....................................................................................................
      for variant, idx of variants
        variant       = ignore_ptag variant
        continue if variant is glyph
        yield @new_entry db,
          null, 'glyph', glyph
          'has/usage/variant', idx
          null, 'glyph', variant, resume
    #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    local_entry_count   = 0
    for glyph, usagecode of usagecode_by_glyph
      local_entry_count += 1
      break if local_entry_count > db[ 'dev-max-entry-count' ]
      #.....................................................................................................
      is_positional_variant = TEXT.ends_with glyph, 'p'
      glyph                 = ignore_ptag glyph
      #.....................................................................................................
      if ( not usagecode? ) or usagecode.length is 0
        if is_positional_variant
          usagecode = 'p'
        else
          continue
      #.....................................................................................................
      yield @new_entry db,
        null, 'glyph', glyph
        'has/usage/code', idx,
        null, 'usage/code', usagecode, resume
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@add_dictionary_data = ( db, handler ) ->
  # sample entry:
  # { strokecodes: [ '4', '44', '441', '25121' ],
  #   beacons: [ '丶', '⺀', '氵', '由' ],
  #   variants: [],
  #   usage: 'CJKTHM',
  #   py: [ 'yóu' ],
  #   py-base: [ 'you' ],
  #   ka: [ 'ユ', 'ユウ' ],
  #   hi: [ 'あぶら' ],
  #   hg: [ '유' ],
  #   gloss: 'oil, fat, grease, lard; paints' }
  #.........................................................................................................
  local_entry_count           = 0
  dictionary_idx              = -1
  #.........................................................................................................
  step ( resume ) =>*
    dictionary_data = yield read_dictionary_data resume
    #.......................................................................................................
    for glyph in dictionary_data[ '%sorting' ]
      local_entry_count += 1
      break if local_entry_count > db[ 'dev-max-entry-count' ]
      # log '©0o0', TRM.pink glyph
      #.....................................................................................................
      dictionary_entry  = dictionary_data[ glyph ]
      # sid               = yield @_fetch_id db, null, 'glyph', glyph, resume
      idx               = -1
      #.....................................................................................................
      dictionary_idx += 1
      pk              = 'has/dictionary/idx'
      ot              = 'i'
      ok              = 'dictionary/idx'
      ov              = dictionary_idx
      yield @new_entry db, null, 'glyph', glyph, pk, dictionary_idx, ot, ok, ov, resume
      #.....................................................................................................
      for tag in [ 'py', 'ka', 'hi', 'hg' ]
        readings = dictionary_entry[ tag ]
        continue unless readings?
        ok = "reading/#{tag}"
        pk = "has/#{ok}"
        #...................................................................................................
        for reading in readings
          idx        += 1
          #.................................................................................................
          yield @new_entry db,
            null, 'glyph', glyph
            pk, idx,
            null, ok, reading, resume
      #.....................................................................................................
      if ( tonal_py_readings = dictionary_entry[ 'py' ] )?
        idx           = -1
        seen_py_bases = {}
        ok            = 'reading/py/base'
        pk            = "has/#{ok}"
        for tonal_py_reading in tonal_py_readings
          base_py_reading = base_py_from_tonal_py tonal_py_reading
          continue if seen_py_bases[ base_py_reading ]
          seen_py_bases[ base_py_reading ] = 1
          idx += 1
          yield @new_entry db, null, 'glyph', glyph, pk, idx, null, ok, base_py_reading, resume
      #.....................................................................................................
      idx = 0
      if ( ov = dictionary_entry[ 'gloss' ] )?
        pk  = 'has/gloss'
        ok  = 'gloss/en'
        #...................................................................................................
        yield @new_entry db, null, 'glyph', glyph, pk, idx, null, ok, ov, resume
      #.....................................................................................................
      ### TAINT: terminology mismatch—'guides' is the new 'beacons' ###
      if ( guides = dictionary_entry[ 'beacons' ] )?
        pk  = 'has/dictionary/guide'
        ok  = 'glyph'
        for ov, idx in guides
          yield @new_entry db, null, 'glyph', glyph, pk, idx, null, ok, ov, resume
      #.....................................................................................................
      if ( strokecodes = dictionary_entry[ 'strokecodes' ] )?
        pk  = 'has/dictionary/strokecode'
        ok  = 'dictionary/strokecode'
        for ov, idx in strokecodes
          yield @new_entry db, null, 'glyph', glyph, pk, idx, null, ok, ov, resume
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@add_components_and_consequential_pairs = ( db, handler ) ->
  report_memory_usage()
  local_entry_count   = 0
  #.........................................................................................................
  step ( resume ) =>*
    components_by_glyph = yield DSB.read_components_by_chr  'global', resume
    carriers_by_glyph   = yield DSB.read_carriers_by_chr    'global', resume
    #.......................................................................................................
    for glyph, components of components_by_glyph
      local_entry_count += 1
      break if local_entry_count > db[ 'dev-max-entry-count' ]
      log TRM.steel local_entry_count, glyph, ( components.join '' ) if local_entry_count % 1000 is 0
      #.....................................................................................................
      for component, idx in components
        entry             = yield @new_entry db,
          null, 'glyph', glyph
          'has/shape/breakdown/component', idx
          null, 'glyph', component
          resume
      #.....................................................................................................
      carriers_by_consequence   = carriers_by_glyph[ glyph ]
      #.....................................................................................................
      for component in components
        carriers  = carriers_by_consequence[ component ]
        continue unless carriers?
        for carrier, idx in carriers
          ov        = component.concat '<', carrier
          entry     = yield @new_entry db,
            null, 'glyph', glyph
            'has/shape/breakdown/consequential-pair', idx,
            null, 'shape/breakdown/consequential-pair', ov,
            resume
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@add_shape_identity_mappings = ( db, handler ) ->
  #.........................................................................................................
  step ( resume ) =>*
    mappings_by_tag   = yield DSI.read_mappings_by_tag resume
    local_entry_count = 0
    #.......................................................................................................
    for tag, mappings of mappings_by_tag
      pk = "has/shape/identity/tag:#{tag}"
      #.....................................................................................................
      for mapped_glyph, target_glyph of mappings
        local_entry_count += 2
        break if local_entry_count > db[ 'dev-max-entry-count' ]
        #...................................................................................................
        yield @new_entry db,
          null, 'glyph', mapped_glyph
          pk, 0
          null, 'glyph', target_glyph
          resume
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@add_constituents_catalog = ( db, handler ) ->
  #.........................................................................................................
  step ( resume ) =>*
    constituents      = yield DSB.read_constituents_catalog 'global', resume
    constituents      = Object.keys constituents
    local_entry_count = 0
    #.......................................................................................................
    for glyph in constituents
      local_entry_count += 1
      break if local_entry_count > db[ 'dev-max-entry-count' ]
      #.....................................................................................................
      yield @new_entry db,
        null, 'glyph', glyph
        'shape/is-constituent', 0
        'b', 'truth', true
        resume
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@add_guides_hierarchy = ( db, handler ) ->
  #.........................................................................................................
  step ( resume ) =>*
    guides_hierarchy   = yield DSG.read_hierarchy_by_guide resume
    local_entry_count   = 0
    log TRM.pink guides_hierarchy
    # #.......................................................................................................
    # for glyph, guides of guides_by_glyph
    #   local_entry_count += 1
    #   break if local_entry_count > db[ 'dev-max-entry-count' ]
    #   #.....................................................................................................
    #   for guide, idx in guides
    #     yield @new_entry db,
    #       null, 'glyph', glyph
    #       'has/shape/breakdown/guide', idx
    #       null, 'glyph', guide
    #       resume
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null

############################################################################################################
############################################################################################################
############################################################################################################
############################################################################################################
############################################################################################################
############################################################################################################
############################################################################################################
############################################################################################################
############################################################################################################
############################################################################################################
############################################################################################################
############################################################################################################

#-----------------------------------------------------------------------------------------------------------
@add_codepoint_infos = ( db, handler ) ->
  ### TAINT: this method relies on *all* glyph entries being in the cache—which, in a future with refined
  cache handling, may or may not hold. ###
  CHR_ = require '/Users/flow/cnd/node_modules/coffeenode-chr'
  local_entry_count = 0
  #.........................................................................................................
  step ( resume ) =>*
    #.......................................................................................................
    # log '©6t4', TRM.cyan db[ '%cache' ]
    # seen_csgs = {}
    for id, entry of db[ '%cache' ][ 'value-by-id' ]
      continue unless entry[ 'isa' ] is 'node' and entry[ 'key' ] is 'glyph'
      local_entry_count += 18
      break if local_entry_count > db[ 'dev-max-entry-count' ]
      glyph     = entry[ 'value' ]
      glyph_id  = entry[ 'id' ]
      try
        cp_info   = CHR_.analyze glyph, input: 'xncr'
      catch error
        throw error
        # throw error unless TEXT.starts_with error[ 'message' ], 'unknown CSG:'
        # log TRM.red '©8e3', error[ 'message' ]
        # continue
      #.....................................................................................................
      cid_id    = ( yield @fetch_node db, 'cp-info/cid',    cp_info[ 'cid'    ], resume )[ 'id' ]
      csg_id    = ( yield @fetch_node db, 'cp-info/csg',    cp_info[ 'csg'    ], resume )[ 'id' ]
      fncr_id   = ( yield @fetch_node db, 'cp-info/fncr',   cp_info[ 'fncr'   ], resume )[ 'id' ]
      ncr_id    = ( yield @fetch_node db, 'cp-info/ncr',    cp_info[ 'ncr'    ], resume )[ 'id' ]
      rsg_id    = ( yield @fetch_node db, 'cp-info/rsg',    cp_info[ 'rsg'    ], resume )[ 'id' ]
      sfncr_id  = ( yield @fetch_node db, 'cp-info/sfncr',  cp_info[ 'sfncr'  ], resume )[ 'id' ]
      xncr_id   = ( yield @fetch_node db, 'cp-info/xncr',   cp_info[ 'xncr'   ], resume )[ 'id' ]
      #.....................................................................................................
      yield @new_edge db, glyph_id, 'has/cp-info/cid',    cid_id,   0, resume
      yield @new_edge db, glyph_id, 'has/cp-info/csg',    csg_id,   0, resume
      yield @new_edge db, glyph_id, 'has/cp-info/fncr',   fncr_id,  0, resume
      yield @new_edge db, glyph_id, 'has/cp-info/ncr',    ncr_id,   0, resume
      yield @new_edge db, glyph_id, 'has/cp-info/rsg',    rsg_id,   0, resume
      yield @new_edge db, glyph_id, 'has/cp-info/sfncr',  sfncr_id, 0, resume
      yield @new_edge db, glyph_id, 'has/cp-info/xncr',   xncr_id,  0, resume
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null


    #.......................................................................................................
    # # guideinfos_by_xshapeclass   = yield DSG.read_guideinfos_by_xshapeclass                          resume
    # #.......................................................................................................
    # # echo guideinfos_by_xshapeclass
    # # for xhshapeclass, guideinfos of guideinfos_by_xshapeclass
    # #   idx = 0
    # #   for guideinfo in guideinfos
    # #     record = "S<glyph/#{glyph}>P<has/shape/breakdown/guide##{idx}>O<shape/breakdown/guide/#{guide}>"
    #     njs_fs.appendFileSync db_route, record + '\n'
    # #     idx          += 1
    # #     entry_count += 1
    # # log TRM.blue entry_count

############################################################################################################


#===========================================================================================================
# MAIN
#-----------------------------------------------------------------------------------------------------------
@main_ = ( db, method_names, handler ) ->
  ### NB: method `add_codepoint_infos` depends on the cache being filled with all the glyphs that received
  mention somewhere else in the process, and should therefore always come last. ###
  #.........................................................................................................
  t0 = 1 * new Date()
  #.........................................................................................................
  step ( resume ) =>*
    yield POSTER.initialize db, resume
    #.......................................................................................................
    for method_name in method_names
      log()
      log TRM.blue '#######################################################################################'
      log TRM.blue method_name
      log TRM.blue '---------------------------------------------------------------------------------------'
      log()
      yield @[ method_name ] db, resume
    #.......................................................................................................
    log()
    log TRM.blue '#######################################################################################'
    yield POSTER.finalize db, resume
    t1 = 1 * new Date()
    dt = t1 - t0
    log TRM.blue "entry count:  #{db[ 'entry-count' ]}"
    log TRM.blue "dt:           #{parseInt dt / 1000 + 0.5}s"
    handler null, db[ 'entry-count' ]
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
f = ->
  db = MOJIKURA.new_db db_options
  #.........................................................................................................
  append = ( P... ) ->
    ( require 'fs' ).appendFileSync db[ 'log-file-route' ], ( TRM.pen P... ), encoding: 'utf-8'
  #.........................................................................................................
  # process.on 'exit', ->
  #   SOLR.CACHE.log_report db
  #.........................................................................................................
  TIMER = require 'coffeenode-timer'
  #.........................................................................................................
  POSTER.post_output_file = ( TIMER.async_instrumentalize 'post file',  POSTER.post_output_file ).bind POSTER
  POSTER.post_batch       = ( TIMER.async_instrumentalize 'post batch', POSTER.post_batch ).bind POSTER
  MOJIKURA.commit         = ( TIMER.async_instrumentalize 'commit',     MOJIKURA.commit   ).bind MOJIKURA
  #.........................................................................................................
  TIMER.start 'populating MojiKura DB'
  step ( resume ) =>*
    response = yield @main_ db, method_names, resume
    log TRM.green "OK"
    TIMER.stop 'populating MojiKura DB'
    append()
    append TEXT.repeat '-', 108
    append new Date()
    # append "same as previous, but without commit on batch posts"
    append db_options
    append TRM.remove_colors TIMER.report()
    append TIMER.report()
    # append SOLR.CACHE.report db


#===========================================================================================================
# CONFIGARATION
#-----------------------------------------------------------------------------------------------------------
db_options =
  # 'batch-size':             250000
  'batch-size':             50000
  # 'batch-size':           3
  'cache-max-entry-count':  10
  ### used only for testing; should be `Infinity` in production: ###
  'dev-max-entry-count':    Infinity
  # 'dev-max-entry-count':    30
  # 'update-method':        'post-batches'
  'update-method':          'write-file'
  ### in case `update-method` is `write-file`, should we post the temporary data files? ###
  'post-files':             yes
  'clear-db':               yes
  'log-file-route':         log_file_route

#...........................................................................................................
method_names = [
  # 'add_test_entries'
  # 'add_guides_hierarchy'
  'add_strokeorders'
  'add_dictionary_data'
  'add_formulas'
  'add_immediate_constituents'
  'add_constituents_catalog'
  # 'add_variants_and_usagecodes'
  # 'add_shape_identity_mappings'
  # 'add_components_and_consequential_pairs'
  ]
  # 'add_guides'
  # 'add_codepoint_infos'




############################################################################################################

# db = MOJIKURA.new_db db_options
# @add_dictionary_data db

format_number = ( n ) ->
  n       = n.toString()
  f       = ( n ) -> return h n, /(\d+)(\d{3})/
  h       = ( n, re ) -> n = n.replace re, "$1" + "'" + "$2" while re.test n; return n
  return f n

report_memory_usage = ->
  mu = process.memoryUsage()
  log '©5r2',
    ( TRM.grey 'rss'        ), ( TRM.gold format_number mu[ 'rss'       ] )
    ( TRM.grey 'heapTotal'  ), ( TRM.gold format_number mu[ 'heapTotal' ] )
    ( TRM.grey 'heapUsed'   ), ( TRM.gold format_number mu[ 'heapUsed'  ] )
  # after 1, report_memory_usage

# report_memory_usage()
do f.bind @



# py bases
# strokeorders
# guides hierarchy
# guides similarity


#-----------------------------------------------------------------------------------------------------------
base_py_from_tonal_py = ( text ) ->
  R = text
  R = R.replace ///[ Ā  Á  Ǎ  À  ] ///g,     'A'
  R = R.replace ///[ Ē  É  Ě  È  ] ///g,     'E'
  R = R.replace ///[ Ī  Í  Ǐ  Ì  ] ///g,     'I'
  R = R.replace ///[ Ō  Ó  Ǒ  Ò  ] ///g,     'O'
  R = R.replace ///[ Ū  Ú  Ǔ  Ù  ] ///g,     'U'
  R = R.replace ///[ Ǖ  Ǘ  Ǚ  Ǜ  ] ///g,     'Ü'
  R = R.replace /// M̄ | Ḿ  | M̌ | M̀  ///g,     'M'
  R = R.replace /// N̄ | Ń  | Ň  | Ǹ   ///g,     'N'
  R = R.replace ///[ ā  á  ǎ  à  ] ///g,     'a'
  R = R.replace ///[ ē  é  ě  è  ] ///g,     'e'
  R = R.replace ///[ ī  í  ǐ  ì  ] ///g,     'i'
  R = R.replace ///[ ō  ó  ǒ  ò  ] ///g,     'o'
  R = R.replace ///[ ū  ú  ǔ  ù  ] ///g,     'u'
  R = R.replace ///[ ǖ  ǘ  ǚ  ǜ  ] ///g,     'ü'
  R = R.replace /// m̄ | ḿ  | m̌ | m̀  ///g,     'm'
  R = R.replace /// n̄ | ń  | ň  | ǹ ///g,     'n'
  R = R.replace /// ê [ 1234 ] ///g, 'ê'
  R = R.replace /// Ê [ 1234 ] ///g, 'Ê'
  return R





