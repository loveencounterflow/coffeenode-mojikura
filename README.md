
![MojiKura](https://github.com/loveencounterflow/coffeenode-mojikura/raw/master/art/mojikura-logo-small.png "MojiKura")


# CoffeeNode MojiKura

## What is it?

MojiKura (文字倉) is an [Entity / Attribute / Value (EAV)](http://en.wikipedia.org/wiki/Entity%E2%80%93attribute%E2%80%93value_model)
database that uses Apache Lucene / Solr as storage engine. Its name derives from its intended main field of
application: storing facts about glyphs, especially Chinese characters (漢字, CJK ideographs).

The basic idea about EAV is that you refrain from casting your theory about the structure of your knowledge
domain into a rigid table structure; rather, you collect lots and lots of facts in your field of study, cast
them into 'phrases', and store them in a homogenous, simple structure.


## Intro to Phrasal Database

Phrases are modelled on natural language and have three main parts: the subject (identifying the entity
we're talking about; a.k.a. 'the entity') on the one hand, the object (identifying an entity that describes
the subject, a.k.a. 'the value') on the other, and a predicate (identifying the relationship between subject
and object, a.k.a. 'the attribute'). Because phrases are at the very heart of MojiKura, i call it a 'phrasal
database'.

Here are some facts about the characters '業' and '业':

* '業' is a glyph<sup>1</sup>.
* '业' is a glyph.
* '業' is most naturally analyzed as '⿱业𦍎'<sup>2</sup>.
* '業' has '业' as its 1<sup>st</sup> component.
* '業' has '𦍎' as its 2<sup>nd</sup> component.
* '業' is written with 13 strokes.
* '業' has the strokeorder 丨丨丶丿一丶丿一丨丿丶.
* '業' is a variant of '业'.
* '業' is a glyph used in Taiwan, Japan, Korea, Hong Kong and Macau.
* '业' is a glyph used in the PRC.
* '業' is read 'yè' in Chinese.
* '業' is read 'ギョウ', 'ゴウ' or 'わざ' in Japanese.
* '業' is read '업' in Korean.
* '業' can be glossed as 'profession, business, trade'.

> <sup>1</sup>) here used as a technical term similar to Unicode's 'CJK ideograph'

> <sup>2</sup>) using Ideographic Description Characters


This is very much the kind of data that dictionaries and textbooks give you. It's easy to see that all we need
to put this information into a database is a little formalization. Let's start with the predicate: in
"'業' has the strokeorder 丨丨丶丿一丶丿一丨丿丶", the predicate is 'has the strokeorder'. Over the years i've
come to prefer structured identifiers that provide a way of rough categorization of things, so instead of
saying just 'has strokeorder', let's call the predicate 'has/shape/strokeorder'. The 'shape' part classifies
strokeorder together with a number of other facts we can tell about the look of a glyph, which may be useful
for queries.

Now for the object. The way i wrote it above, it is '丨丨丶丿一丶丿一丨丿丶'; however, for ease of search, i prefer to
encode that as '2243143111234'<sup>3</sup>; this is the 'value' of the object. In order to allow for precise searches,
we want to make sure this string won't get wrongly identified as something else—a strokeorder written down
using some other scheme, or a telephone number or anything else. One way to disambiguate pieces of data is
to associate them with a 'key', in this case, naturally enough, i suggest to use
'shape/strokeorder/zhaziwubifa'.

> <sup>3</sup>) This encoding is called 札字五筆法 zházìwǔbǐfǎ, and is one possible way to sort out
> stroke categories. As a mnemonic, it is based on the way the character 札 is written: 一丨丿丶乚.
> Following this model stroke order, we identify horizontals 一 with '1',
> verticals 丨 with '2', left slanting strokes 丿 with '3', right slanting strokes and dots 丶 with '4', and
> all bending strokes such as 乚 with '5'.


Lastly, the subject is obviously '業'. In the terminology adopted here, it is classified as a 'glyph',
which should be good enough to use as the subject key.

Now we have the parts of our phrase:

    subject key:      glyph
    subject type:     業

    predicate:        has/shape/strokeorder

    object key:       shape/strokeorder/zhaziwubifa
    object value:     2243143111234

These facets (key / value pairs) are, in essence, what is going to be stored in the database. We can cast
these parts into a single string, somewhat like a Uniform Resource Identifier (as which it will serve in the
DB). I here adopt the convention to separate the parts of speech by ',' (commas) and key /value pairs by ':'
(colons):

    glyph:業,has/shape/strokeorder,shape/strokeorder/zhaziwubifa:2243143111234

That's neat, because what's more general and more capable than a line of text? One can imagine that a backup
of a phrasal DB can simply consist in a textfile, with each line representing one record.

The astute reader may wonder why we go through the trouble to key the predicate as `has/shape/strokeorder`
and the object as `shape/strokeorder/zhaziwubifa`, which looks rather redundant. The redundancy, however, is
by no means to be found in all phrases; for example, in the statement

  '業' has '业' as its component

'業' is the subject and '业' the object—both of them glyphs, so the phrase for this fact may be written out as

    glyph:業,has/shape/component,glyph:业

which establishes a relationship between two glyphs. The names used here are of course just suggestions;
you could just as well use single words or arbitrary strings, but i like to keep things readable.

There are two slight complications we still have to deal with: for one thing, there might be several phrases
that share a common subject and predicate, but have different values—in the examples given above, that
observation readily applies to the readings and the componential analysis. To accommodate for this, we
bluntly stipulate that each phrase shall bear an index which counts all occurrances of a given subject /
predicate pair, and that the index shall be treated as the 'value' of the predicate, as it were. We can then
write out the facts about the components of '業' as

    glyph:業,has/shape/component:0,glyph:业
    glyph:業,has/shape/component:1,glyph:𦍎

Secondly, there will be facts we do not want to store as texts—prices, lengths, truth values, geographic
locations, dates and so forth; there will even be subjects that should not be stored as texts, e.g. when we
want to state what happened in the year 690 CE<sup>4</sup>, we want to store the subject as a date, since
only then can we take advantage of all the date-related features that Lucene offers. The next section states
that dates are associated with the sigil 'd', and integers with 'i'; in order to get the data type sigil
unambiguously into a phrase, we can put it into round brackets and prefix the subject or object key with
it. Here are two of the seven facts the English Wikipedia has recorded about the year 690:

    (d)year:690,politics/china/emperor/investiture:0,person:wuzetian
    (d)year:690,culture/china/character/created:0,glyph:曌
    (d)year:690,en.wikipedia/trivia/count:0,(i)trivia/count:7

> <sup>4</sup>) trivia: [the character '曌' was created](http://en.wikipedia.org/wiki/Chinese_characters_of_Empress_Wu),
> and [Empress Dowager Wu Zetian ascended the throne](http://en.wikipedia.org/wiki/Wu_Zetian).



## IDs and Meta-Phrases

In databases, it's always nice (and, in the case of Lucene, always necessary) to associate each record with
a unique ID. We have seen above that each entry in the MojiKura Phrasal DB can be unambiguously turned into
a URL-like phrase, and vice-versa. Conceivably, we could then go and stipulate that the ID of an entry
shall be its phrase, which is straightforward. H



## Database Structure and Field Names

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

Special text types:

    *.m:      'meta', a phrase ID       # allows to make statements about phrases

## Sample Data Set

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


    glyph/業:has/shape/strokeorder#0:shape/strokeorder/zhaziwubifa/2243143111234

      subject-key:      glyph
      subject-value:    業
      predicate:        has/shape/strokeorder
      idx:              0
      object-key:       shape/strokeorder/zhaziwubifa
      object-value:     2243143111234


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


