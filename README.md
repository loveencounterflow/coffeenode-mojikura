
![MojiKura](https://github.com/loveencounterflow/coffeenode-mojikura/raw/master/art/mojikura-logo-small.png "MojiKura")


# CoffeeNode MojiKura

MojiKura (文字倉) is an [Entity / Attribute / Value (EAV)](http://en.wikipedia.org/wiki/Entity%E2%80%93attribute%E2%80%93value_model)
database that uses Apache Lucene / Solr as storage engine. Its name derives from its intended main field of
application: storing facts about glyphs, especially Chinese characters (漢字, CJK ideographs).

The basic idea about EAV is that you refrain from casting your theory about the structure of your knowledge
domain into a rigid table structure; rather, you collect lots and lots of facts in your field of study, cast
them into 'phrases', and store them in a homogenous, simple structure. Phrases are modelled on natural
language and have three main parts: the subject (identifying the entity we're talking about; a.k.a. 'the
entity') on the one hand, the object (identifying an entity that describes the subject, a.k.a. 'the value')
on the other, and a predicate (identifying the relationship between subject and object, a.k.a. 'the
attribute'). Here are some facts about the characters '業' and '业':

* '業' is a glyph<sup>1</sup>.
* '业' is a glyph.
* '業' is most naturally analyzed as '⿱业𦍎'<sup>2</sup>.
* '業' has '业' as its 1<sup>st</sup> component.
* '業' has '𦍎' as its 2<sup>nd</sup> component.
* '業' is written with 13 strokes
* '業' has the strokeorder 丨丨丶丿一丶丿一丨丿丶.
* '業' is a variant of '业'.
* '業' is a glyph used in Taiwan, Japan, Korea, Hong Kong and Macau.
* '业' is a glyph used in the PRC.
* '業' is read 'yè' in Chinese.
* '業' is read 'ギョウ', 'ゴウ' or 'わざ' in Japanese.


  <sup>1</sup>) here used as a technical term similar to Unicode's 'CJK ideograph'

  <sup>2</sup>) using Ideographic Description Characters

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


