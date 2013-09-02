



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
db_route                  = njs_path.join '/tmp', 'mojikura2-study.mjkrdb'
batch_size                = 10
batch                     = []
record_count              = 0
written_record_count      = 0

# #-----------------------------------------------------------------------------------------------------------
# get_entries = ( db ) ->
#   R = []
#   R.push MOJIKURA.new_node db, 'glyph', '國'
#   R.push MOJIKURA.new_node db, 'glyph', '或'
#   R.push MOJIKURA.new_node db, 'glyph',            '王'
#   R.push MOJIKURA.new_node db, 'glyph',            '𤣩'
#   R.push MOJIKURA.new_node db, 'glyph',            CHR.chrs_from_text '一二龶&jzr#xe189;夊黽', input: 'xncr'
#   R.push MOJIKURA.new_node db, 'glyph',            '习'
#   R.push MOJIKURA.new_node db, 'reading/py/tonal', 'wáng'
#   R.push MOJIKURA.new_node db, 'reading/py/base',  'wang'
#   R.push MOJIKURA.new_node db, 'usage/code',       'CJKTHM'
#   R.push MOJIKURA.new_node db, 'flag',             yes
#   R.push MOJIKURA.new_node db, 'flag',             no
#   R.push MOJIKURA.new_edge db, 'glyph/國', 'shape/contains', 'glyph/或', 0
#   R.push MOJIKURA.new_edge db, 'reading/py/tonal/wáng', 'has/reading/py/base',               'reading/py/base/wang', 0
#   R.push MOJIKURA.new_edge db, 'glyph/𤣩',               'has/shape/identity/tag:components', 'glyph/王',              0
#   R.push MOJIKURA.new_edge db, 'glyph/王',               'has/usage/code',                    'usage/code/CJKTHM',    0
#   R.push MOJIKURA.new_edge db, 'glyph/王',               'has/reading/py/tonal',              'reading/py/tonal/wáng',0
#   R.push MOJIKURA.new_edge db, 'glyph/习',               'is/constituent',                    'flag/true',             0
#   R.push MOJIKURA.new_edge db, 'glyph/习',               'is/guide',                          'flag/true',             0
#   return R

#-----------------------------------------------------------------------------------------------------------
@_clear_output_file = ( db ) ->
  njs_fs.writeFileSync db_route, '[\n'

#-----------------------------------------------------------------------------------------------------------
@_append_to_output_file = ( db ) ->
  if batch.length is 0
    njs_fs.appendFileSync db_route, '\n' #]\n'
  else
    if written_record_count is 0
      njs_fs.appendFileSync db_route, batch.join ',\n'
    else
      njs_fs.appendFileSync db_route, ',\n'.concat ( batch.join ',\n' ) # , '\n]\n'
  written_record_count += batch.length
  batch.length = 0

#-----------------------------------------------------------------------------------------------------------
@_finalize_output_file = ( db ) ->
  @_append_to_output_file db
  njs_fs.appendFileSync db_route, '\n]\n'
  batch.length = 0

#-----------------------------------------------------------------------------------------------------------
@_add_entry = ( db, entry ) ->
  batch.push JSON.stringify entry
  record_count += 1
  if record_count % 1000 is 0
    log TRM.pink record_count
    MOJIKURA.log_cache_report db
  @_append_to_output_file db if batch.length >= batch_size

#-----------------------------------------------------------------------------------------------------------
@populate = ( db, handler ) ->
  @_clear_output_file db
  DATASOURCES   = require '/Users/flow/JIZURA/flow/library/DATASOURCES'
  # njs_fs.writeFileSync db_route, ''
  #=========================================================================================================
  step ( resume ) =>*
    #.......................................................................................................
    DSB               = DATASOURCES.SHAPE.BREAKDOWN
    DSG               = DATASOURCES.SHAPE.GUIDES
    batch             = []
    #.......................................................................................................
    formulas_by_glyph           = yield DSB.read_formulas_by_chr                          'global', resume
    # ics_by_glyph                = yield DSB.read_preferred_immediate_constituents_by_chr  'global', resume
    # guides_by_glyph             = yield DSG.read_guides_by_glyph                          'global', resume
    # # guideinfos_by_xshapeclass   = yield DSG.read_guideinfos_by_xshapeclass                          resume
    # variants_and_usage_by_glyph = yield DATASOURCES.VARIANTUSAGE.read_variants_and_usage_by_chr     resume
    # #.......................................................................................................
    # [ variants_by_glyph
    #   usagecode_by_glyph ]      = variants_and_usage_by_glyph
    # variants_by_glyph           = variants_by_glyph[ 'elements' ]
    #.......................................................................................................
    for glyph, formulas of formulas_by_glyph
      log TRM.pink glyph
      break if record_count > 67 # 89 # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      #.....................................................................................................
      # idx         = 0
      glyph_id    = MOJIKURA.get_node_id db, 'glyph', glyph
      log TRM.yellow '©7z7', glyph_id
      glyph_entry = yield MOJIKURA.get db, glyph_id, null, resume
      #.....................................................................................................
      if glyph_entry is null
        glyph_entry = MOJIKURA.new_node db, 'glyph', glyph
        log TRM.red '©7z8', glyph_entry[ 'id' ]
        @_add_entry db, glyph_entry
      #.....................................................................................................
      for formula, idx in formulas
        formula_id    = MOJIKURA.get_node_id db, 'shape/breakdown/formula', formula
        formula_entry = yield MOJIKURA.get db, formula_id, null, resume
        #.....................................................................................................
        if formula_entry is null
          formula_entry = MOJIKURA.new_node db, 'shape/breakdown/formula', formula
          @_add_entry db, glyph_entry
        #.....................................................................................................
        edge_entry    = MOJIKURA.new_edge db, glyph_id, 'has/shape/breakdown/formula', formula_id, idx
        @_add_entry db, edge_entry
        #.....................................................................................................
        idx          += 1
    #.......................................................................................................
    log TRM.blue record_count
    @_finalize_output_file db

    # #.......................................................................................................
    # for glyph, ics of ics_by_glyph
    #   idx = 0
    #   for ic in ics
    #     record = "S<glyph/#{glyph}>P<has/shape/breakdown/ic##{idx}>O<shape/breakdown/ic/#{ic}>"
    #     # njs_fs.appendFileSync db_route, record + '\n'
    #     idx          += 1
    #     record_count += 1
    # log TRM.blue record_count
    # #.......................................................................................................
    # for glyph, guides of guides_by_glyph
    #   idx = 0
    #   for guide in guides
    #     record = "S<glyph/#{glyph}>P<has/shape/breakdown/guide##{idx}>O<shape/breakdown/guide/#{guide}>"
    #     # njs_fs.appendFileSync db_route, record + '\n'
    #     idx          += 1
    #     record_count += 1
    # log TRM.blue record_count
    # #.......................................................................................................
    # # echo guideinfos_by_xshapeclass
    # # for xhshapeclass, guideinfos of guideinfos_by_xshapeclass
    # #   idx = 0
    # #   for guideinfo in guideinfos
    # #     record = "S<glyph/#{glyph}>P<has/shape/breakdown/guide##{idx}>O<shape/breakdown/guide/#{guide}>"
    #     njs_fs.appendFileSync db_route, record + '\n'
    # #     idx          += 1
    # #     record_count += 1
    # # log TRM.blue record_count
    # #.......................................................................................................
    # for glyph, variants of variants_by_glyph
    #   idx = 0
    #   for variant of variants
    #     continue if variant is glyph
    #     record = "S<glyph/#{glyph}>P<has/shape/variant##{idx}>O<shape/variant/#{variant}>"
    #     # njs_fs.appendFileSync db_route, record + '\n'
    #     idx          += 1
    #     record_count += 1
    # log TRM.blue record_count
    # #.......................................................................................................
    # for glyph, usagecode of usagecode_by_glyph
    #   continue if ( not usagecode? ) or usagecode.length is 0
    #   idx     = 0
    #   record  = "S<glyph/#{glyph}>P<has/usage/code##{idx}>O<usage/code/#{usagecode}>"
    #   # njs_fs.appendFileSync db_route, record + '\n'
    #   idx          += 1
    #   record_count += 1
    # log TRM.blue record_count
    # #.......................................................................................................
    handler null, record_count

############################################################################################################
db = MOJIKURA.new_db()
# throw new Error "obacht"
@populate db, ( error, response ) ->
  throw error if error?
  #.........................................................................................................
  log TRM.blue response

# @_clear_output_file db
# for idx in [ 0 .. 123 ]
#   @_add_entry db, "#{idx}"
# @_finalize_output_file db






