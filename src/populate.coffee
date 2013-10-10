

###

TAINT missing methods:

strokecounts
guides hierarchy
guides similarity

###



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


#-----------------------------------------------------------------------------------------------------------
base_py_from_tonal_py = ( text ) ->
  ### TAINT this method shouldn't be here ###
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

#===========================================================================================================
# OBJECT CREATION
#-----------------------------------------------------------------------------------------------------------
@get_entry = ( db, cache, t, k, v ) ->
  target    = cache[ k ]?= {}
  R         = target[ v ]
  return R if R?
  return target[ v ] = MOJIKURA.new_entry db, t, k, v

#-----------------------------------------------------------------------------------------------------------
@_entries_from_cache = ( db, cache ) ->
  R         = []
  for k, target of cache
    for v, node of target
      R.push node
  return R

#-----------------------------------------------------------------------------------------------------------
@_clear_cache = ( db, cache ) ->
  for k of cache
    delete cache[ k ]
  return null

#-----------------------------------------------------------------------------------------------------------
@push = ( P... ) -> return MOJIKURA.push P...

#-----------------------------------------------------------------------------------------------------------
@save_cached_entries = ( db, cache, handler ) ->
  nodes = @_entries_from_cache db, cache
  @_clear_cache db, cache
  return POSTER.save_nodes db, nodes, handler

#-----------------------------------------------------------------------------------------------------------
@_cache_ics_by_glyph      = {}
@_cache_components_by_glyph = {}

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
# ADDITIONAL DATA AGGREGATORS
# should go into DATASOURCES later
#-----------------------------------------------------------------------------------------------------------
@find_carriers = ( db, glyph ) ->
  #.........................................................................................................
  R = @_find_carriers db, glyph, {}, {}
  R = ( carrier for carrier of R ) #.sort()
  #.........................................................................................................
  return R

#-----------------------------------------------------------------------------------------------------------
@_find_carriers = ( db, glyph, seen_glyphs, carriers ) ->
  return carriers if seen_glyphs[ glyph ]?
  seen_glyphs[ glyph ] = 1
  #.........................................................................................................
  ics         = @_cache_ics_by_glyph[        glyph ]
  components  = @_cache_components_by_glyph[ glyph ]
  #.........................................................................................................
  if ics?
    local_carriers = {}
    for ic in ics
      carrier                   = ic.concat ':', glyph
      local_carriers[ carrier ] = 1
      carriers[ carrier ]       = 1
  #.........................................................................................................
  if components?
    if ics?
      components      = ( component for component in components when ( ics.indexOf component ) is -1 )
  if ics?
    for ic in ics
      @_find_carriers db, ic, seen_glyphs, carriers
  #.........................................................................................................
  return carriers


#===========================================================================================================
# DATA COLLECTING
#-----------------------------------------------------------------------------------------------------------
@add_strokeorders = ( db, cache, handler ) ->
  #.........................................................................................................
  step ( resume ) =>*
    strokeorders_by_glyph = yield DSS.read_strokeorders_by_chr 'global', resume
    local_entry_count     = 0
    #.......................................................................................................
    for glyph, strokeorders of strokeorders_by_glyph
      local_entry_count += 1
      break if local_entry_count > db[ 'dev-max-entry-count' ]
      glyph_entry = @get_entry db, cache, null, 'glyph', glyph
      #.....................................................................................................
      for strokeorder in strokeorders
        #...................................................................................................
        @push db, glyph_entry, 'strokeorder', strokeorder
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@add_formulas = ( db, cache, handler ) ->
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
      glyph_entry   = @get_entry db, cache, null, 'glyph', glyph
      #.....................................................................................................
      for formula in formulas
        seen_formulas[ formula ]  = 1
        @push db, glyph_entry, 'formula', formula
      #.....................................................................................................
      for formula, idx in corrected_formulas_by_glyph[ glyph ]
        continue if seen_formulas[ formula ]?
        @push db, glyph_entry, 'corrected-formula', formula
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@add_immediate_constituents = ( db, cache, handler ) ->
  #.........................................................................................................
  step ( resume ) =>*
    formulas_by_glyph = yield DSB.read_formulas_by_chr 'global', resume
    ic_lists_by_glyph = yield DSB.read_immediate_constituents_by_chr  'global', resume
    local_entry_count = 0
    seen_formulas     = {}
    #.......................................................................................................
    for glyph, ic_lists of ic_lists_by_glyph
      local_entry_count += 1
      break if local_entry_count > db[ 'dev-max-entry-count' ]
      glyph_entry   = @get_entry db, cache, null, 'glyph', glyph
      cache_entry   = @_cache_ics_by_glyph[ glyph ] = []
      formulas      = formulas_by_glyph[ glyph ]
      #.....................................................................................................
      seen_ics = {}
      for ics, idx in ic_lists
        formula       = formulas[ idx ]
        #...................................................................................................
        unless seen_formulas[ formula ]?
          formula_entry = @get_entry db, cache, null, 'formula', formula
          for ic in ics
            @push db, formula_entry, 'ic', ic
        #...................................................................................................
        for ic in ics
          continue if seen_ics[ ic ]
          seen_ics[ ic ] = 1
          ic_node  = @get_entry db, cache, null, 'glyph', ic
          @push db, glyph_entry, 'ic', ic
          cache_entry.push ic
        #...................................................................................................
        seen_formulas[ formula ] = 1
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@add_variants_and_usagecodes = ( db, cache, handler ) ->
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
      glyph        = ignore_ptag glyph
      glyph_entry  = @get_entry db, cache, null, 'glyph', glyph
      #.....................................................................................................
      for variant of variants
        variant       = ignore_ptag variant
        continue if variant is glyph
        variant_entry = @get_entry db, cache, null, 'glyph', variant
        @push db, glyph_entry, 'variant', variant
    #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    for glyph, usagecode of usagecode_by_glyph
      local_entry_count += 1
      break if local_entry_count > db[ 'dev-max-entry-count' ]
      #.....................................................................................................
      is_positional_variant = TEXT.ends_with glyph, 'p'
      glyph                 = ignore_ptag glyph
      glyph_entry           = @get_entry db, cache, null, 'glyph', glyph
      #.....................................................................................................
      if ( not usagecode? ) or usagecode.length is 0
        if is_positional_variant
          usagecode = 'p'
        else
          continue
      #.....................................................................................................
      @push db, glyph_entry, 'usagecode', usagecode
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@add_dictionary_data = ( db, cache, handler ) ->
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
      #.....................................................................................................
      glyph_entry         = @get_entry db, cache, null, 'glyph', glyph
      dictionary_entry    = dictionary_data[ glyph ]
      dictionary_idx     += 1
      @push db, glyph_entry, 'dictionary-idx', dictionary_idx
      #.....................................................................................................
      for tag in [ 'py', 'ka', 'hi', 'hg' ]
        readings = dictionary_entry[ tag ]
        continue unless readings?
        #...................................................................................................
        for reading in readings
          @push db, glyph_entry, tag, reading
      #.....................................................................................................
      if ( tonal_py_readings = dictionary_entry[ 'py' ] )?
        seen_py_bases = {}
        for tonal_py_reading in tonal_py_readings
          base_py_reading = base_py_from_tonal_py tonal_py_reading
          continue if seen_py_bases[ base_py_reading ]
          seen_py_bases[ base_py_reading ] = 1
          @push db, glyph_entry, 'py-base', base_py_reading
      #.....................................................................................................
      if ( gloss = dictionary_entry[ 'gloss' ] )?
        @push db, glyph_entry, 'gloss', gloss
      #.....................................................................................................
      ### TAINT: terminology mismatch—'guides' is the new 'beacons' ###
      if ( guides = dictionary_entry[ 'beacons' ] )?
        for guide in guides
          @push db, glyph_entry, 'guide', guide
      #.....................................................................................................
      if ( strokecodes = dictionary_entry[ 'strokecodes' ] )?
        for strokecode in strokecodes
          @push db, glyph_entry, 'strokecode', strokecode
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@add_components_and_carriers = ( db, cache, handler ) ->
  ics_ok = no
  for ignored of @_cache_ics_by_glyph
    ics_ok = yes
    break
  throw new Error "must run read_immediate_constituents_by_chr first" unless ics_ok
  #.........................................................................................................
  local_entry_count   = 0
  #.........................................................................................................
  step ( resume ) =>*
    components_by_glyph = yield DSB.read_components_by_chr  'global', resume
    # carriers_by_glyph   = yield DSB.read_carriers_by_chr    'global', resume
    # ic_lists_by_glyph   = yield DSB.read_immediate_constituents_by_chr  'global', resume
    #.......................................................................................................
    for glyph, components of components_by_glyph
      #.....................................................................................................
      local_entry_count += 1
      break if local_entry_count > db[ 'dev-max-entry-count' ]
      log TRM.steel local_entry_count, glyph, ( components.join '' ) if local_entry_count % 10000 is 0
      glyph_entry = @get_entry db, cache, null, 'glyph', glyph
      cache_entry = @_cache_components_by_glyph[ glyph ] = []
      #.....................................................................................................
      for component in components
        component_entry = @get_entry db, cache, null, 'glyph', component
        @push db, glyph_entry, 'component', component
        cache_entry.push component
    #.......................................................................................................
    local_entry_count = 0
    for glyph, components of components_by_glyph
      glyph_entry = @get_entry db, cache, null, 'glyph', glyph
      carriers    = @find_carriers db, glyph
      local_entry_count += 1
      if local_entry_count % 10000 is 0
        carriers_txt = ( ( TRM.gold carrier ) for carrier in carriers ).join ', '
        log ( TRM.grey local_entry_count ), glyph, carriers_txt
      for carrier in carriers
        @push db, glyph_entry, 'carrier', carrier
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@add_shape_identity_mappings = ( db, cache, handler ) ->
  #.........................................................................................................
  step ( resume ) =>*
    mappings_by_tag   = yield DSI.read_mappings_by_tag resume
    local_entry_count = 0
    #.......................................................................................................
    for tag, mappings of mappings_by_tag
      pk = "mapped-to/#{tag}"
      #.....................................................................................................
      for source_glyph, target_glyph of mappings
        #...................................................................................................
        rsg = CHR.as_rsg source_glyph
        ### Glyphs from these ranges have been introduced solely in order to get rid of whacky components
        in the original formulas; as they are clearly no CJK ideographs, we do not want these to appear
        in the database. ###
        continue if rsg is 'u-bopo'
        continue if rsg is 'u-boxdr'
        continue if rsg is 'u-cjk-cmpf'
        continue if rsg is 'u-cjk-kata'
        continue if rsg is 'u-geoms'
        continue if rsg is 'u-halfull'
        continue if rsg is 'u-punct'
        #...................................................................................................
        local_entry_count += 2
        break if local_entry_count > db[ 'dev-max-entry-count' ]
        source_entry = @get_entry db, cache, null, 'glyph', source_glyph
        target_entry = @get_entry db, cache, null, 'glyph', target_glyph
        #...................................................................................................
        @push db, source_entry, pk, target_glyph
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@add_constituents_catalog = ( db, cache, handler ) ->
  #.........................................................................................................
  step ( resume ) =>*
    constituents      = yield DSB.read_constituents_catalog 'global', resume
    constituents      = Object.keys constituents
    local_entry_count = 0
    #.......................................................................................................
    for glyph in constituents
      local_entry_count += 1
      break if local_entry_count > db[ 'dev-max-entry-count' ]
      glyph_entry = @get_entry db, cache, null, 'glyph', glyph
      @push db, glyph_entry, 'is-constituent', true
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@add_guides_hierarchy = ( db, cache, handler ) ->
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
  # CHR_ = require '/Users/flow/cnd/node_modules/coffeenode-chr'
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
        cp_info   = CHR.analyze glyph, input: 'xncr'
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
      cache = {}
      yield @[ method_name ] db, cache, resume
      yield @save_cached_entries db, cache, resume
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
  MOJIKURA.update_from_file = ( TIMER.async_instrumentalize 'post file',  MOJIKURA.update_from_file ).bind MOJIKURA
  # POSTER.post_output_file = ( TIMER.async_instrumentalize 'post file',  POSTER.post_output_file ).bind POSTER
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
  'batch-size':             1e4
  # 'batch-size':             10
  ### used only for testing; should be `Infinity` in production: ###
  'dev-max-entry-count':    Infinity
  # 'dev-max-entry-count':    30
  # 'update-method':          'post-batches'
  'update-method':          'write-file'
  ### in case `update-method` is `write-file`, should we post the temporary data files? ###
  'post-files':             yes
  'clear-db':               yes
  'log-file-route':         log_file_route

#...........................................................................................................
method_names = [
  'add_formulas'
  'add_strokeorders'
  'add_dictionary_data'
  'add_variants_and_usagecodes'
  'add_immediate_constituents' # must come *before* `add_components_and_carriers`
  'add_components_and_carriers' # must come *after* `add_immediate_constituents`
  'add_shape_identity_mappings'
  'add_constituents_catalog'

  # 'add_test_entries'
  # 'add_guides_hierarchy'
  ]
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

# UCD = require 'jizura-ucd'
# UCD.read_cid_ranges_by_scriptname ( error, cid_ranges_by_scriptname ) ->
#   throw error if error?
#   #.........................................................................................................
#   cjk_cid_ranges = cid_ranges_by_scriptname[ 'Han' ]
#   for range in cjk_cid_ranges
#     [ min_cid, max_cid ] = range
#     log ( min_cid.toString 16 ), ( max_cid.toString 16 ) #, ( rpr scriptname )




# #-----------------------------------------------------------------------------------------------------------
# foo = ->
#   # report_memory_usage()
#   local_entry_count   = 0
#   phrase_count        = 0
#   #.........................................................................................................
#   step ( resume ) =>*
#     # components_by_glyph = yield DSB.read_components_by_chr  'global', resume
#     # carriers_by_glyph   = yield DSB.read_carriers_by_chr    'global', resume
#     ic_lists_by_glyph   = yield DSB.read_immediate_constituents_by_chr  'global', resume
#     for glyph in CHR.chrs_from_text '抓爬㼌笊孤𢱑'
#     # log TRM.rainbow carriers_by_glyph[ '嶽' ]
#     # log TRM.rainbow components_by_glyph[ '嶽' ]
#       seen_ics  = {}
#       cps       = []
#       for ics in ic_lists_by_glyph[ glyph ]
#         for ic in ics
#           continue if seen_ics[ ic ]?
#           seen_ics[ ic ] = 1
#           for sub_ics in ic_lists_by_glyph[ ic ]
#             for sub_ic in sub_ics
#               cps.push sub_ic.concat ':', ic
#       log TRM.rainbow glyph, cps.join ', '

# foo()



