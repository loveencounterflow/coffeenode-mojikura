

###

A simplistic reader for Lucene Solr Data Schemas; see http://wiki.apache.org/solr/SchemaXml.

It only reads the `<fields/>` section of `schema.xml`; there, only the `<uniqueKey/>` setting and
(static) `<field>` definitions are recognized; of the latter, solely attribute `multiValued` is
parsed.

There must be no `<dynamicField/> elements in `schema.xml` (as yet).


###

############################################################################################################
njs_fs                    = require 'fs'
#...........................................................................................................
XPATH                     = require 'xpath'
XMLDOM                    = require 'xmldom'


#-----------------------------------------------------------------------------------------------------------
@read = ( db ) ->
  schema_route = db[ 'schema-route' ]
  throw new Error "unable to find entry `schema-route` in DB object" unless schema_route?
  #.........................................................................................................
  xml = njs_fs.readFileSync schema_route, encoding: 'utf-8'
  #.........................................................................................................
  R =
    '~isa':           'MOJIKURA/db-schema'
    'field-by-name':  {}
    'unique-key':     null
  #.........................................................................................................
  ### weirdest object creation API choice ever: ###
  document  = new XMLDOM.DOMParser().parseFromString xml
  nodes     = XPATH.select "//fields/*", document
  #.........................................................................................................
  for node in nodes
    switch node[ 'localName' ]
      #.....................................................................................................
      when 'field'
        for name in [ 'name', 'type', 'multiValued', ]
          #.................................................................................................
          if R[ name ]?
            throw new Error "duplicate field:\n  #{node.toString()}\n"
          #.................................................................................................
          name            = node.getAttribute 'name'
          is_multivalued  = node.getAttribute 'multiValued'
          is_multivalued  = if is_multivalued is 'true' then yes else no
          #.................................................................................................
          if ( not name? ) or name.length is 0
            throw new Error "no field name:\n  #{node.toString()}\n"
          #.................................................................................................
          R[ name ] =
            # 'name':             name
            'is-multi':         is_multivalued
      #.....................................................................................................
      when 'dynamicField'
        throw new Error "dynamic fields are not supported (yet):\n  #{node.toString()}\n"
      #.....................................................................................................
      else
        throw new Error "unknown field type:\n  #{node.toString()}\n"
  #.........................................................................................................
  nodes = XPATH.select "//uniqueKey", document
  for node in nodes
    key = node.firstChild.data
    if ( not key? ) or key.length is 0
      throw new Error "found <uniqueKey/> but no field name:\n  #{node.toString()}\n"
    R[ 'unique-key' ] = key
    break
  #.........................................................................................................
  return R


############################################################################################################


###

xml = """

<schema>
  <fields>
    <field name="greetings">helo</field>
    <field name='k' type="string"   multiValued="false" indexed="true" stored="true"/>
    <field name='ks' type="string"   multiValued="true" indexed="true" stored="true"/>
    <!--
    <field>world</field>
    -->
    </fields>
    <uniqueKey>id</uniqueKey>

  </schema>


"""

console.log @read()

###