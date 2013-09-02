



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
# db_route                  = njs_path.join __dirname, 'data/mojikura2-study.mjkrdb'


#-----------------------------------------------------------------------------------------------------------
get_entries = ( db ) ->
  R = []
  R.push MOJIKURA.new_node db, 'glyph', '國'
  R.push MOJIKURA.new_node db, 'glyph', '或'
  R.push MOJIKURA.new_node db, 'glyph',            '王'
  R.push MOJIKURA.new_node db, 'glyph',            '𤣩'
  R.push MOJIKURA.new_node db, 'glyph',            CHR.chrs_from_text '一二龶&jzr#xe189;夊黽', input: 'xncr'
  R.push MOJIKURA.new_node db, 'glyph',            '习'
  R.push MOJIKURA.new_node db, 'reading/py/tonal', 'wáng'
  R.push MOJIKURA.new_node db, 'reading/py/base',  'wang'
  R.push MOJIKURA.new_node db, 'usage/code',       'CJKTHM'
  R.push MOJIKURA.new_node db, 'flag',             yes
  R.push MOJIKURA.new_node db, 'flag',             no
  R.push MOJIKURA.new_edge db, 'glyph/國', 'shape/contains', 'glyph/或', 0
  R.push MOJIKURA.new_edge db, 'reading/py/tonal/wáng', 'has/reading/py/base',               'reading/py/base/wang', 0
  R.push MOJIKURA.new_edge db, 'glyph/𤣩',               'has/shape/identity/tag:components', 'glyph/王',              0
  R.push MOJIKURA.new_edge db, 'glyph/王',               'has/usage/code',                    'usage/code/CJKTHM',    0
  R.push MOJIKURA.new_edge db, 'glyph/王',               'has/reading/py/tonal',              'reading/py/tonal/wáng',0
  R.push MOJIKURA.new_edge db, 'glyph/习',               'is/constituent',                    'flag/true',             0
  R.push MOJIKURA.new_edge db, 'glyph/习',               'is/guide',                          'flag/true',             0
  return R


#-----------------------------------------------------------------------------------------------------------
@populate = ( db, handler ) ->
  record_count  = 0
  DATASOURCES   = require '/Users/flow/JIZURA/flow/library/DATASOURCES'
  # njs_fs.writeFileSync db_route, ''
  #=========================================================================================================
  step ( resume ) =>*
    #.......................................................................................................
    DSB               = DATASOURCES.SHAPE.BREAKDOWN
    DSG               = DATASOURCES.SHAPE.GUIDES
    buffer            = []
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
      if record_count % 1000 is 0
        log TRM.pink record_count
        MOJIKURA.log_cache_report db
        ignored       = yield SOLR.update db, buffer, resume
        buffer.length = 0
      #.....................................................................................................
      idx         = 0
      ### TAINT: ID should come from MojiKura ###
      glyph_id    = "glyph/#{glyph}"
      glyph_entry = yield MOJIKURA.get db, glyph_id, null, resume
      #.....................................................................................................
      unless glyph_entry?
        glyph_entry = MOJIKURA.new_node db, 'glyph', glyph
        glyph_id    = glyph_entry[ 'id' ]
        buffer.push glyph_entry
      #.....................................................................................................
      for formula in formulas
        ### TAINT: ID should come from MojiKura ###
        formula_id    = "shape/breakdown/formula/#{formula}"
        formula_entry = yield MOJIKURA.get db, formula_id, null, resume
        #.....................................................................................................
        unless formula_entry?
          formula_entry = MOJIKURA.new_node db, 'shape/breakdown/formula', formula
          formula_id    = formula_entry[ 'id' ]
          buffer.push formula_entry
        #.....................................................................................................
        edge_entry    = MOJIKURA.new_edge db, glyph_id, 'has/shape/breakdown/formula', formula_id, idx
        buffer.push edge_entry
        #.....................................................................................................
        idx          += 1
        record_count += 1
    #.......................................................................................................
    log TRM.blue record_count
    if buffer.length > 0
      ignored       = yield SOLR.update db, buffer, resume
      buffer.length = 0

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
throw new Error "obacht"
@populate db, ( error, response ) ->
  throw error if error?
  #.........................................................................................................
  log TRM.blue response









