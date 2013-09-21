
![MojiKura](https://github.com/loveencounterflow/coffeenode-mojikura/raw/master/art/mojikura-logo-small.png "MojiKura")


# CoffeeNode MojiKura

MojiKura (文字倉) is an (Entity / Attribute / Value (EAV))[http://en.wikipedia.org/wiki/Entity%E2%80%93attribute%E2%80%93value_model]
database that uses Apache Lucene / Solr as storage engine. Its name derives from its intended main field of
application: storing facts about glyphs, especially Chinese characters.

## Sample Data Set

Each entry in the database is an object (dubbed an 'entry' or a 'phrase') with the following fieldnames:

    sk          (subject key)
    st          (subject type)
    sv          (subject value)
    p           (predicate)
    idx         (index)
    ok          (object key)
    ot          (object type)
    ov          (object value)

The value fields—`sv` and `ov`—are special because they have to accommodate various data types. The default
data type is `text` (implemented as `solr.TrieDateField`) and is left unmarked. Values of other data types
must use field names ending with one of the suffixes from this overview:

    *.i:      integer                   solr.TrieIntField
    *.il:     long                      solr.TrieFloatField
    *.id:     double                    solr.TrieDoubleField
    *.f:      float                     solr.TrieLongField
    *.b:      boolean                   solr.BoolField
    *.d:      tdate                     solr.TrieDateField
    *.j:      text (arbitrary JSON)     solr.TrieDateField

So in order to store, say, a strokecount, field `ov.i` (object integer value) must be used.


    glyph/業:has/usage/code#0:usage/code/JKTHM

      subject-key:      glyph
      subject-value:    業
      predicate:        has/usage/code
      idx:              0
      object-key:       usage/code
      object-value:     JKTHM


    glyph/业:has/usage/code#0:usage/code/C

      subject-key:      glyph
      subject-value:    业
      predicate:        has/usage/code
      idx:              0
      object-key:       usage/code
      object-value.t:   C


    glyph/業:has/shape/strokecount#0:(i)shape/strokecount/13

      subject-key:      glyph
      subject-value:    業
      predicate:        has/usage/code
      idx:              0
      object-key:       shape/strokecount
      object-type:      n
      object-value.i:   13


    glyph/業:has/shape/breakdown/formula#0:breakdown/formula/⿱业𦍎

      subject-key:      glyph
      subject-value:    業
      predicate:        has/shape/breakdown/formula
      idx:              0
      object-key:       shape/breakdown/formula
      object-value:     ⿱业𦍎


    glyph/業:has/shape/breakdown/component#0:glyph/业

      subject-key:      glyph
      subject-value:    業
      predicate:        has/shape/breakdown/component
      idx:              0
      object-key:       glyph
      object-value:     业


    glyph/業:has/shape/breakdown/component#1:glyph/𦍎

      subject-key:      glyph
      subject-value:    業
      predicate:        has/shape/breakdown/component
      idx:              1
      object-key:       glyph
      object-value:     𦍎


    glyph/業:has/usage/variant#0:glyph/业

      subject-key:      glyph
      subject-value:    業
      predicate:        has/usage/variant
      idx:              0
      object-key:       glyph
      object-value:     业


    glyph/业:has/usage/variant#0:glyph/業

      subject-key:      glyph
      subject-value:    业
      predicate:        has/usage/variant
      idx:              0
      object-key:       glyph
      object-value:     業


