


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
#...........................................................................................................
log_file_route            = njs_path.join __dirname, '../data/log.txt'
#...........................................................................................................
# DATASOURCES               = require '/Users/flow/JIZURA/flow/library/DATASOURCES'
# DSB                       = DATASOURCES.SHAPE.BREAKDOWN
# DSG                       = DATASOURCES.SHAPE.GUIDES
# DSI                       = DATASOURCES.SHAPE.IDENTITY



#===========================================================================================================
# OBJECT CREATION
#-----------------------------------------------------------------------------------------------------------
@fetch_node = ( db, key, value, handler ) ->
  node_id   = MOJIKURA.get_node_id db, key, value
  retrieve  = => @new_node db, key, value, handler
  # log TRM.cyan '©7z8 populate.fetch_node'
  #.........................................................................................................
  MOJIKURA.CACHE.retrieve db, node_id, retrieve, ( error, Z ) =>
    # log TRM.cyan '©7z8 populate.fetch_node/retrieve (cb)'
    return handler error if error?
    handler null, Z
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@new_node = ( db, key, value, handler ) ->
  return @_new db, 'new_node', key, value, handler

#-----------------------------------------------------------------------------------------------------------
@new_edge = ( db, from_id, key, to_id, idx, handler ) ->
  return @_new db, 'new_edge', from_id, key, to_id, idx, handler

#-----------------------------------------------------------------------------------------------------------
@_new = ( db, method_name, P..., handler ) ->
  #.........................................................................................................
  # log TRM.cyan '©7z5 populate._new'
  MOJIKURA[ method_name ] db, P..., ( error, Z ) =>
    return handler error if error?
    #.......................................................................................................
    POSTER.add_entry db, Z, ( error ) =>
      # log TRM.pink '©7z5 populate._new (cb)'
      return handler error if error?
      handler null, Z
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@get_node_id = ( db, key, value ) ->
  return MOJIKURA.get_node_id db, key, value

#-----------------------------------------------------------------------------------------------------------
@get_edge_id = ( db, from_id, key, to_id, idx ) ->
  return MOJIKURA.get_edge_id db, from_id, key, to_id, idx


#===========================================================================================================
# DATA COLLECTING
#-----------------------------------------------------------------------------------------------------------
@add_formulas = ( db, handler ) ->
  #.........................................................................................................
  step ( resume ) =>*
    formulas_by_glyph = yield DSB.read_formulas_by_chr 'global', resume
    local_entry_count = 0
    #.......................................................................................................
    for glyph, formulas of formulas_by_glyph
      local_entry_count += 2
      break if local_entry_count > db[ 'dev-max-entry-count' ]
      #.....................................................................................................
      glyph_entry = yield @fetch_node db, 'glyph', glyph, resume
      glyph_id    = glyph_entry[ 'id' ]
      # log TRM.orange '©2d3', glyph_entry
      #.....................................................................................................
      for formula, idx in formulas
        formula_entry = yield @fetch_node db, 'shape/breakdown/formula', formula, resume
        formula_id    = formula_entry[ 'id' ]
        # log TRM.yellow '©2d4', formula_entry
        edge_entry = yield @new_edge db, glyph_id, 'has/shape/breakdown/formula', formula_id, idx, resume
        # log TRM.gold '©2d5', edge_entry
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@add_test_entries = ( db, handler ) ->
  #.........................................................................................................
  step ( resume ) =>*
    entry = yield @fetch_node db, 'test/text',      'just a text',  resume
    entry = yield @fetch_node db, 'test/list',      [ 1, 2, 3, ],   resume
    entry = yield @fetch_node db, 'test/boolean',   yes,            resume
    entry = yield @fetch_node db, 'test/boolean',   no,             resume
    # entry[ '%is-clean' ] = yes
    entry = yield @fetch_node db, 'test/pod',       foo: 'bar',     resume
    for n in [ 1024 ... 1050 ]
      entry = yield @fetch_node db, 'test/number',    n,             resume
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@add_immediate_constituents = ( db, handler ) ->
  #.........................................................................................................
  step ( resume ) =>*
    ics_by_glyph      = yield DSB.read_preferred_immediate_constituents_by_chr  'global', resume
    local_entry_count = 0
    #.......................................................................................................
    for glyph, ics of ics_by_glyph
      local_entry_count += 2
      break if local_entry_count > db[ 'dev-max-entry-count' ]
      #.....................................................................................................
      glyph_entry = yield @fetch_node db, 'glyph', glyph, resume
      glyph_id    = glyph_entry[ 'id' ]
      #.....................................................................................................
      for ic, idx in ics
        ic_entry    = yield @fetch_node db, 'glyph', ic, resume
        ic_id       = ic_entry[ 'id' ]
        yield @new_edge db, glyph_id, 'has/shape/breakdown/ic', ic_id, idx, resume
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null

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

#-----------------------------------------------------------------------------------------------------------
@add_shape_identity_mappings = ( db, handler ) ->
  #.........................................................................................................
  step ( resume ) =>*
    mappings_by_tag   = yield DSI.read_mappings_by_tag resume
    local_entry_count = 0
    #.......................................................................................................
    for tag, mappings of mappings_by_tag
      predicate = "has/shape/identity/tag:#{tag}"
      #.....................................................................................................
      for mapped_glyph, target_glyph of mappings
        local_entry_count += 2
        break if local_entry_count > db[ 'dev-max-entry-count' ]
        #...................................................................................................
        mapped_glyph_entry = yield @fetch_node db, 'glyph', mapped_glyph, resume
        mapped_glyph_id    = mapped_glyph_entry[ 'id' ]
        target_glyph_entry = yield @fetch_node db, 'glyph', target_glyph, resume
        target_glyph_id    = target_glyph_entry[ 'id' ]
        #...................................................................................................
        yield @new_edge db, mapped_glyph_id, predicate, target_glyph_id, 0, resume
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
    true_node         = yield @fetch_node db, 'flag', true, resume
    false_node        = yield @fetch_node db, 'flag', false, resume
    true_id           = true_node[  'id' ]
    false_id          = false_node[ 'id' ]
    #.......................................................................................................
    for glyph in constituents
      local_entry_count += 1
      break if local_entry_count > db[ 'dev-max-entry-count' ]
      #.....................................................................................................
      glyph_entry = yield @fetch_node db, 'glyph', glyph, resume
      glyph_id    = glyph_entry[ 'id' ]
      #.....................................................................................................
      yield @new_edge db, glyph_id, 'shape/is-constituent', true_id, 0, resume
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@add_guides = ( db, handler ) ->
  #.........................................................................................................
  step ( resume ) =>*
    guides_by_glyph   = yield DSG.read_guides_by_glyph 'global', resume
    local_entry_count = 0
    #.......................................................................................................
    for glyph, guides of guides_by_glyph
      local_entry_count += 2
      break if local_entry_count > db[ 'dev-max-entry-count' ]
      #.....................................................................................................
      glyph_entry = yield @fetch_node db, 'glyph', glyph, resume
      glyph_id    = glyph_entry[ 'id' ]
      #.....................................................................................................
      for guide, idx in guides
        guide_entry = yield @fetch_node db, 'glyph', guide, resume
        guide_id    = guide_entry[ 'id' ]
        edge = yield @new_edge db, glyph_id, 'has/shape/breakdown/guide', guide_id, idx, resume
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@add_components = ( db, handler ) ->
  #.........................................................................................................
  step ( resume ) =>*
    components_by_glyph = yield DSB.read_components_by_chr 'global', resume
    local_entry_count   = 0
    #.......................................................................................................
    for glyph, components of components_by_glyph
      local_entry_count += 2
      break if local_entry_count > db[ 'dev-max-entry-count' ]
      #.....................................................................................................
      glyph_entry = yield @fetch_node db, 'glyph', glyph, resume
      glyph_id    = glyph_entry[ 'id' ]
      #.....................................................................................................
      for component, idx in components
        component_entry = yield @fetch_node db, 'glyph', component, resume
        component_id    = component_entry[ 'id' ]
        edge = yield @new_edge db, glyph_id, 'has/shape/breakdown/component', component_id, idx, resume
    #.......................................................................................................
    handler null, null
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@add_consequential_pairs = ( db, handler ) ->
  #.........................................................................................................
  step ( resume ) =>*
    carriers_by_glyph   = yield DSB.read_carriers_by_chr 'global', resume
    local_entry_count   = 0
    # log TRM.rainbow '©4t1', carriers_by_glyph[ '國']
    # log TRM.rainbow '©4t1', carriers_by_glyph[ '木']
    # process.exit()
    #.......................................................................................................
    for glyph, carriers_by_consequence of carriers_by_glyph
      local_entry_count += 2
      break if local_entry_count > db[ 'dev-max-entry-count' ]
      #.....................................................................................................
      glyph_entry         = yield @fetch_node db, 'glyph', glyph, resume
      glyph_id            = glyph_entry[ 'id' ]
      consequential_pairs = []
      #.....................................................................................................
      for consequence, carriers of carriers_by_consequence
        for carrier in carriers
          consequential_pairs.push consequence.concat carrier
      #.....................................................................................................
      ### TAINT: we format the consequential pairs to form an 'easily searchable string'. It could be argued
      that this should be the job of a suitable decoder/encoder pair, or that the list should be committed
      as such. It would also be possible to commit each consequential pair separately to the DB, however,
      this would add *a lot* of nodes and edges. ###
      consequential_pairs = ','.concat ( consequential_pairs.join ',' ), ','
      cps_entry           = yield @fetch_node db, 'consequential-pairs', consequential_pairs, resume
      cps_id              = cps_entry[ 'id' ]
      #.....................................................................................................
      yield @new_edge db, glyph_id, 'has/shape/breakdown/consequential-pairs', cps_id, 0, resume
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
      local_entry_count += 2
      break if local_entry_count > db[ 'dev-max-entry-count' ]
      #.....................................................................................................
      glyph       = ignore_ptag glyph
      glyph_entry = yield @fetch_node db, 'glyph', glyph, resume
      glyph_id    = glyph_entry[ 'id' ]
      #.....................................................................................................
      for variant, idx of variants
        variant       = ignore_ptag variant
        continue if variant is glyph
        variant_entry = yield @fetch_node db, 'glyph', variant, resume
        variant_id    = variant_entry[ 'id' ]
        yield @new_edge db, glyph_id, 'has/usage/variant', variant_id, idx, resume
    #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    local_entry_count   = 0
    for glyph, usagecode of usagecode_by_glyph
      local_entry_count += 2
      break if local_entry_count > db[ 'dev-max-entry-count' ]
      #.....................................................................................................
      is_positional_variant = TEXT.ends_with glyph, 'p'
      glyph                 = ignore_ptag glyph
      glyph_entry           = yield @fetch_node db, 'glyph', glyph, resume
      glyph_id              = glyph_entry[ 'id' ]
      #.....................................................................................................
      if ( not usagecode? ) or usagecode.length is 0
        if is_positional_variant
          usagecode = 'p'
        else
          continue
      #.....................................................................................................
      usagecode_entry = yield @fetch_node db, 'usage/code', usagecode, resume
      usagecode_id    = usagecode_entry[ 'id' ]
      yield @new_edge db, glyph_id, 'has/usage/code', usagecode_id, 0, resume
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
# throw new Error "obacht"


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
  process.on 'exit', ->
    SOLR.CACHE.log_report db
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
    # append TRM.remove_colors TIMER.report()
    append TIMER.report()
    append SOLR.CACHE.report db


#===========================================================================================================
# CONFIGARATION
#-----------------------------------------------------------------------------------------------------------
db_options =
  'batch-size':             250000
  # 'batch-size':           3
  'cache-max-entry-count':  10
  ### used only for testing; should be `Infinity` in production: ###
  'dev-max-entry-count':    Infinity
  # 'dev-max-entry-count':      80
  # 'update-method':        'post-batches'
  'update-method':          'write-file'
  ### in case `update-method` is `write-file`, should we post the temporary data files? ###
  'post-files':             no
  # '%data-file-routes':       []
  'clear-db':               yes
  'log-file-route':         log_file_route

#...........................................................................................................
method_names = [
  'add_test_entries'
  # 'add_consequential_pairs'
  # 'add_components'
  # 'add_shape_identity_mappings'
  # 'add_constituents_catalog'
  # 'add_formulas'
  # 'add_immediate_constituents'
  # 'add_variants_and_usagecodes'
  # 'add_guides'
  # 'add_codepoint_infos'
  ]


############################################################################################################
do f.bind @

# test_cache = ->
#   P = @
#   step ( resume ) =>*
#     log yield P.fetch_node db, 'foo', 42, resume
#     yield after 0.1, resume
#     log TRM.gold yield P.fetch_node db, 'bar', 42, resume
#     yield after 0.1, resume
#     log yield P.fetch_node db, 'baz', 42, resume
#     yield after 0.1, resume
#     log yield P.fetch_node db, 'gnu', 42, resume
#     # yield after 0.1, resume
#     # log yield P.fetch_node db, 'yatzee', 108, resume
#     yield after 0.1, resume
#     log TRM.gold yield P.fetch_node db, 'bar', 42, resume
#     mru = db[ '%cache' ][ '%mru' ]
#     while not mru.empty()
#       entry = mru.pop()
#       log TRM.rainbow entry[ 'key' ], entry[ '%touched' ]
#     log db[ '%cache' ]

