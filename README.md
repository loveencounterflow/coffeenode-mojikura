
![MojiKura](https://github.com/loveencounterflow/coffeenode-mojikura/raw/master/art/mojikura-logo-small.png "MojiKura")


# CoffeeNode MojiKura

## What is it?


MojiKura <ruby><rb>文字倉</rb><rp>(</rp><rt>もじくら</rt><rp>)</rp></ruby> is a Lucene Solr document database
which, while of generic structure built on top of `coffeenode-solr`, is intended to lend itself especially
for storing data about Unicode codepoints, specifically those that represent Chinese characters (漢字, CJK
ideographs). Nothing keeps you from using MojiKura to store just about anything—its design is fully general.


<!--
n [Entity / Attribute / Value
(EAV)](http://en.wikipedia.org/wiki/Entity%E2%80%93attribute%E2%80%93value_model) database module for NodeJS
that uses Apache Lucene / Solr as storage engine. Its name derives from its intended main field of
application: storing facts about glyphs, especially Chinese characters (漢字, CJK ideographs). Nothing keeps
you from using MojiKura to store just about anything—its design is fully general.

The basic idea about EAV is that you refrain from casting your theory about the structure of your knowledge
domain into a rigid table structure as you would in a classical relational DB management system (RDBMS);
rather, you collect lots and lots of facts in your field of study, cast them into 'phrases', and store them
in a homogenous, simple structure.


## Implementation Status

Be warned that only portions of this code are readily usable now; everything is in flux.


## Intro: Phrasal Databases

Phrases are modelled on natural language and have three main parts: the subject (identifying the entity
we're talking about; a.k.a. 'the entity') on the one hand, the object (identifying an entity that describes
the subject, a.k.a. 'the value') on the other, and a predicate (identifying the relationship between subject
and object, a.k.a. 'the attribute'). Because phrases are at the very heart of MojiKura, i call it a 'phrasal
database'.

Here are some facts about the characters '業' and '业':

* "業" is a glyph<sup>1</sup>.
* "业" is a glyph.
* "業" is most naturally analyzed as "⿱业𦍎"<sup>2</sup>.
* "業" has "业" as its 1<sup>st</sup> component.
* "業" has "𦍎" as its 2<sup>nd</sup> component.
* "業" is written with 13 strokes.
* "業" has the strokeorder 丨丨丶丿一丶丿一一一丨丿丶.
* "業" is a variant of "业".
* "業" is a glyph used in Taiwan, Japan, Korea, Hong Kong and Macau.
* "业" is a glyph used in the PRC.
* "業" is read "yè" in Chinese.
* "業" is read "ギョウ", "ゴウ" or "わざ" in Japanese.
* "業" is read "업" in Korean.
* "業" can be glossed as "profession, business, trade".

> <sup>1</sup>) here used as a technical term similar to Unicode's 'CJK ideograph'

> <sup>2</sup>) using Ideographic Description Characters


This is very much the kind of data that dictionaries and textbooks give you. It's easy to see that all we need
to put this information into a database is a little formalization.

Let's start with the **predicate**: in

* "業" has the strokeorder "丨丨丶丿一丶丿一一一丨丿丶"

the predicate is 'has the strokeorder'. Over the years i've come to prefer structured identifiers that
provide a way of rough categorization of things, so instead of saying just 'has strokeorder', let's call it
`has/shape/strokeorder`. The 'shape' part classifies strokeorder together with a number of other fact
categories we can tell about the look of a glyph (components, formula, strokecount), which may be useful
for queries.

Now for the **object**. The way i wrote it above, it is "丨丨丶丿一丶丿一一一丨丿丶"; however, for ease of search, i
prefer to encode that as "2243143111234"<sup>1</sup>; this is the value of the object. In order to allow for
precise searches, we want to make sure this string won't get wrongly identified as something else—a
strokeorder written down using some other scheme, or a telephone number or anything else. One way to
disambiguate pieces of data is to associate them with a 'key'; in this case i suggest to use
`shape/strokeorder/zhaziwubifa`.

> <sup>1</sup>) This encoding is called 札字五筆法 zházìwǔbǐfǎ, and is one possible way to sort out
> stroke categories. As a mnemonic, it is based on the way the character 札 is written: 一丨丿丶乚.
> Following this model stroke order, we identify horizontals 一 with '1',
> verticals 丨 with '2', left slanting strokes 丿 with '3', right slanting strokes and dots 丶 with '4', and
> all bending strokes such as 乚 with '5'.


Lastly, the **subject** value is "業". In the terminology adopted here, the entity we're talking about is
termed a `glyph`, a word which should be good enough to use as the subject key (assuming a small controlled
vocabulary for a specific knowledge domain).

Now we have the parts of our phrase:

    subject key:      'glyph'
    subject value:    "業"

    predicate:        'has/shape/strokeorder'

    object key:       'shape/strokeorder/zhaziwubifa'
    object value:     "2243143111234"

These facets (key / value pairs) are, in essence, what is going to be stored in the database. We can cast
the facets into a single string, somewhat like a Uniform Resource Identifier (as which it will serve in the
DB). I here adopt the convention to separate the parts of speech by ',' (commas) and key / value pairs by ':'
(colons):

    glyph:"業",has/shape/strokeorder,shape/strokeorder/zhaziwubifa:"2243143111234"

That's neat, because **what's more general and more versatile than a line of text?** One can imagine that a backup
of a PhraseDB can simply consist in a textfile, with each line representing one record.

The astute reader may wonder why we go through the trouble to key the predicate as `has/shape/strokeorder`
and the object as `shape/strokeorder/zhaziwubifa`, which looks rather redundant. The redundancy, however, is
by no means to be found in all phrases; for example, in the statement

* "業" has "业" as its component

"業" is the subject and "业" the object—both of them glyphs, so the phrase for this fact may be written out as

    glyph:"業",has/shape/component,glyph:"业"

which establishes a relationship between two glyphs. The names used here are of course just suggestions;
you could just as well use single words or arbitrary strings, but i like to keep things readable.

There are two slight complications we still have to deal with: for one thing, there might be several phrases
that share a common subject and predicate, but have different values—in the examples given above, that
observation readily applies to the readings and the componential analysis. To accommodate for this, we
bluntly stipulate that each phrase shall bear an index which counts all occurrances of a given subject /
predicate pair, and that the index shall be treated as the 'value' of the predicate, as it were. Using
zero-based indices we can then write out the facts about the components of "業" as

    glyph:"業",has/shape/component:0,glyph:"业"
    glyph:"業",has/shape/component:1,glyph:"𦍎"

Secondly, there will be object values we do not want to store as texts—prices, lengths, truth values, geographic
locations, dates and so forth; there will even be subjects that should not be stored as texts, e.g. when we
want to state what happened in the year 690 CE<sup>1</sup>, we want to store the subject as a date, since
only then can we take advantage of all the date-related features that Lucene offers. The next section states
that dates are associated with the sigil 'd', and integers with 'i'; in order to get the data type sigil
unambiguously into a phrase, we can put it into round brackets and prefix the subject or object key with
it. Here are two of the seven facts the English Wikipedia has recorded about the year 690, and one meta-fact:

    (d)year:690,politics/china/emperor/investiture:0,person:"wuzetian"
    (d)year:690,culture/china/character/created:0,glyph:"曌"
    (d)year:690,en.wikipedia/trivia/count:0,(i)trivia/count:7

> <sup>1</sup>) trivia: [the character "曌" was created](http://en.wikipedia.org/wiki/Chinese_characters_of_Empress_Wu),
> and [Empress Dowager Wu Zetian ascended the throne](http://en.wikipedia.org/wiki/Wu_Zetian).

We still have to specify which fields have to be set to which values using our generalized schema.
In anticipitation of the field names as listed in [Database Structure and Field Names](#database-structure-and-field-names),
below, we add two optional fields `st` (for subject type) and `ot` (for object type); these are text values
themselves and destined to hold the respective data type sigil whenever the data type is anything but a plain
text. Next, we cannot use the fields `sv` and `ov`, since Lucene only stores one particular data type in
one particular field; instead, we use the value field name (`sv` or `ov`) suffixed with a period and the
data type sigil (giving us e.g. `sv.d` for a date subject value and `ov.i` for an integer object value):

    (d)year:690,politics/china/emperor/investiture:0,person:"wuzetian"

    sk:       'year'
    st:       'd'
    sv.d:     690
    pk:       'politics/china/emperor/investiture'
    pi:       0
    ok:       'person'
    ov:       "wuzetian"


    (d)year:690,en.wikipedia/trivia/count:0,(i)trivia/count:7

    sk:       'year'
    st:       'd'
    sv.d:     690
    pk:       'en.wikipedia/trivia/count'
    pi:       0
    ok:       trivia/count
    ot:       'i'
    ov.i:     7

Note: whether `person:"wuzetian"` is precise enough to uniquely identify the historical figure will depend
on your application; it is here merely used as a placeholder. You could resort to using real-world URLs as
identifiers (as in `(url)person:"http://en.wikipedia.org/wiki/Wu_Zetian"`) or use existential assertions
(for which see below).


## Rules of Serialization

In this section we define how to transform a PhraseDB entry into a 'phrase'—a succint URL-like notation
that reflects all aspects of a valid entry.

### Phrase Layout

All phrases are written out in a single line representing subject, predicate and object in this order;
optionally, the phrase ID may be prepended. Each of the three mandatory parts are spelled out as

    type_rpr( type ) + key_rpr( key ) + ':' + value_rpr( value )

### Keys

Keys are serialized without quotes; they may not contain any whitespace, commas, or colons, or unprintable
characters or control codes.

### Values

#### Basic Values

The most basic data type are `null`, Booleans, numbers and text; their MojiKura phrase serializations are
defined as their [JSON representations](http://www.json.org/), more specifically, whatever
a call to `JSON.stringify( x )` (within NodeJS) yields.<sup>1</sup>

> <sup>1</sup> which means that texts are serialized with surrounding double quotes; double quotes,
> newlines, tab characters and backslashes are escaped with a backslash and rendered as `\"`, `\n`, `\t`,
> `\\`, respectively



#### Extended Values
### Optional IDs

XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX
XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX
XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX
XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX

## IDs and Meta-Phrases

In databases, it's always nice (and, in the case of Lucene, always necessary) to associate each record with
a unique ID. We have seen above that each entry in the MojiKura PhraseDB can be unambiguously turned into
a URL-like phrase, and vice-versa. Conceivably, we could then go and stipulate that the ID of an entry
shall be its phrase, which is straightforward. However, i prefer to go a step further and **use a hash of the
entry phrase as ID** instead of the phrase itself; that way, we avoid to repeat potentially long strings just for the
ID, and we gain the ability to form meta-phrases with less hassle.

> Implementation detail: i'm currently using the first 12 characters of the hexadecimal representation of the
> SHA-256 cryptographic digest of the entry phrase as hash. The choice of the hash algorithm and length is rather
> arbitrary; in the future, the algorithm will likely be substituted by a non-cryptographic hash, which is
> potentially faster without sacrificing the important properties of a hash, namely, to uniquely identify texts
> with a low probability of a hash collision.

Why does a hash ID help in formulating meta-phrases?—Consider the phrase about '曌' from above:

    (d)year:690,culture/china/character/created:0,glyph:"曌"

Imagine we want to state that the source of this fact is a certain article on Wikipedia:

    x,has/source:0,(url)web:"http://en.wikipedia.org/wiki/Wu_Zetian"

what piece of data should we use to identify the subject of that phrase? The subject is itself an entry
in the database, so it would be natural to use its ID. If, however, we used phrases as IDs, we would get
something like

    phrase:"(d)year:690,culture/china/character/created:0,glyph:\"曌\"",has/source:0,(url)web:"http://en.wikipedia.org/wiki/Wu_Zetian"

which is unwieldy to say the least. It doesn't scale, either. A Wikipedia page can change anytime, so maybe
we want to add a meta-phrase to that meta-phrase

    x,as/read/on:0,(d)date:"2013-09-22"

Substituting the next-to-last phrase to this meta-phrase and applying the Rules of Serialization we get
a big ball of spaghetti:

    phrase:"phrase:\"(d)year:690,culture/china/character/created:0,glyph:\\\"曌\\\"\",has/source:0,(url)web:\"http://en.wikipedia.org/wiki/Wu_Zetian\"",as/read/on:0,(d)date:"2013-09-22"

You can probably see where this is going—it's leading nowhere.

Now, given that in the current scheme the ID
of the first phrase, above, is `b5a24bdcf75b` and the data type sigil for phrase IDs is 'm', we can rewrite
the first meta-phrase as

    (m)phrase:"b5a24bdcf75b",has/source:0,(URL)web:"http://en.wikipedia.org/wiki/Wu_Zetian"

Now the ID of *this* phrase is computed as `c1cc225d2e09`, so our meta-meta-phrase becomes simply

    (m)phrase:"4ae2f0bfbc27",as/read/on:0,(d)date:"2013-09-22"

Hashes as IDs, then, allow us to formulate meta-phrases as succinctly as ordinary, non-meta phrases—both
kinds actually look identical.

XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX
XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX
XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX
XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX
XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX
XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX
XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX XXXXXX

* **`sk: entity`**: used to make a statement about an entity; subject value is the ID of an existential
  assertion phrase.

* **`sk: phrase`**: used to make a statement about a phrase; subject value is the ID of an existential
  assertion or a regular SPO phrase.

* **`sk: relation`**: used to make a statement about a relation; subject value is the ID of a regular SPO
  phrase.


## Existential Assertion Phrases

Most phrase examples in this readme use what could be termed 'implicit existential claims', that is, there
are phrases like `glyph:業,has/shape/component:1,glyph:𦍎` which implicitly claim that objects of class
`glyph`, identified as `業` and `𦍎`, do exist. Sometimes that much will be fine, sometimes such claims had
better be made explicit, which is what Existential Assertion Phrases (EAPs) are for.

An EAP simple states 'there exists an entity that has this key and this value of this type'. For example,
each character must consist of at least one stroke, and in general, a stroke count is a non-negative
integer number. When your database consists of no more than the scant data sample outlined in the intro,
above, you will have only data about glyphs with 5, 8, and 13 strokes. If you now go and build a catalog
with that data, maybe you want to make it explicit that stroke counts like 4 or 10 have no associated
glyphs, although real world knowledge tells you there will be glyphs with 4 and 10 strokes as soon as you
add but a few dozends more glyphs to the base. Maybe you have a collection of some yet undescribed
characters gleaned from some piece of literature, say '天地玄黄'—you know these glyphs exist, but you have no
data as yet to describe them.

I suggest it makes sense, in these cases, to use minimal entries to assert existence of an entity. A minimal
entry has a subject key, type, and value, but no predicate and no object. According to the [Rules of
Serialization](#rules-of-serialization), minimal phrases will then look like these:

    id:"bfd1aa72d40a"|glyph:"業",:0,:
    id:"dc60be6df1e8"|glyph:"业",:0,:
    id:"4c2fad02aa73"|glyph:"𦍎",:0,:
    id:"9181a08d8d98"|glyph:"天",:0,:
    id:"ea7071978d7c"|glyph:"地",:0,:
    id:"8e55073ca1b3"|glyph:"玄",:0,:
    id:"4566f086afc6"|glyph:"黄",:0,:
    id:"3c6943c0f146"|(i)shape/strokecount:1,:0,:
    id:"225427e0af9a"|(i)shape/strokecount:2,:0,:
    id:"387978c7bd69"|(i)shape/strokecount:3,:0,:
    ...

Existential phrases make good targets for connecting assertions to entities (i.e. stating facts about things).
Much like the meta-phrases introduced in the previous section XXXXXXXXXXX

    glyph:"業",has/shape/component:0,glyph:"业"
    glyph:"業",has/shape/component:1,glyph:"𦍎"

    (m)entity:"bfd1aa72d40a",has/shape/component:0,(m)entity:"dc60be6df1e8"
    (m)entity:"bfd1aa72d40a",has/shape/component:1,(m)entity:"4c2fad02aa73"




## A Word on Normalization

In the world of RDBMSes, normalization is a kind of fetish. Much work goes into designing table structures
to atomize complex data and thinking up complicated queries to re-join those bits and pieces. There are, to
be sure, strong reasons to take normalization seriously, one of them being data integrity, another one
(at least historically and still today in huge data sets) being avoidance of wasteful duplication.

MojiKura does nothing to ensure data integrity. Maybe in the future it will, but there are no plans at
this point in time. The good thing about this is that it makes MojiKura easier to understand, thereby
lowering the entry barrier. The bad thing is that your data may not be in a shape you want it to be, without
you even noticing. It is perfectly possible to mistype keys, or to add multiple values where only a single
value is allowed. Imagine one day you find these two meta-phrases in your collection:

    (m)phrase:"2a82f9bcbc27",added:0,(d)date:"2013-11-11"
    (m)phrase:"2a82f9bcbc27",addid:1,(d)date:"2013-11-12"

How many errors can you spot? There are (probably) three: One, it makes little sense to record two different
times a given fact has entered the database (note the identical subject IDs). Two, there's (probably) a
spelling error in the second phrase. Three, the index of the second phrase is (probably) bogus, assuming
there is no phrase matching `(m)phrase:"2a82f9bcbc27",addid:0,*`. As it stands, MojiKura does not check
keys, values or indices—that's your job.

I like to think about data normalization and data integrity much like i think about static / strict vs.
dynamic / loose / duck typing in programming languages: static typing is *awesome* when it's optional, and
it's a nightmare when it's mandatory. That's because static typing puts constraints into the programm that
makes it too strict to easily handle some problems (try to store integers and strings in a single list using
Java), but fails in the field of advanced value checking.

Now the reason static typing and SQL field constraints fail so miserably when it comes to value checking is
connected with the fact that both are typically expressed in a purely declarative manner. Consider this
SQL statement:

    CREATE TABLE suppliers (
      supplier_id   NUMBER(10) NOT NULL,
      supplier_name VARCHAR2(50) NOT NULL,
      contact_name  VARCHAR2(50) );

It does capture the fact that an ID is a ten-digit number, and that a name is a text of variable with up
to 50 characters. Beyond that (and maybe checking foreign keys) it does nothing to make sure your data
makes any sense.

As a practical example, consider that all the sample phrases in this readme assume that a 'glyph' is reified
as "a text with a single Unicode code point representing a CJK ideograph". Now what exactly does and does
not match this definition is open to contention.<sup>1</sup> This means that in order to check for real data
integrity, we need a lot of domain-specific knowledge—far beyond the reach of the static types you'll find
in typical RDBMSes or static programming languages.

> <sup>1</sup>) In my book, that does not really cover most characters in Unicode blocks like the [Kangxi Radicals](http://en.wikipedia.org/wiki/Radical_%28Chinese_characters%29#Unicode)
> and the [compatibility characters](http://en.wikipedia.org/wiki/Unicode_compatibility_characters#Compatibility_Blocks).

Likewise, while i can imagine there is something to say in favor of having MojiKura check for sane indexes
on phrases, nothing short of a full-blown programming language is powerful enough to check for more
'interesting' higher-order potential sources of data integrity failures. For instance, consider that in
order to be consistent, phrases like

    glyph:"業",has/shape/strokeorder,shape/strokeorder/zhaziwubifa:"2243143111234"
    glyph:"業":has/shape/strokecount#0:(i)shape/strokecount:13

should not contradict each other. Now, an integrity check here implies having to count the characters in
the object value of the first phrase and seeing whether that equals the object value of the second phrase.
It gets more complicated when you take CJK glyphs with more than one valid strokeorder (where even the
number of strokes can vary) into the equation.

The outcome of the above discussion is simple: make it a habit to ckeck whatever you feel is worth checking
up front when / before data enters the DB, and when you're done populating the DB or after data got modified
or added, perform any reasonable number of integrity checks.


## Database Structure and Field Names

Each entry in the database—what Lucene calls a 'document'—is a (JavaScript) object (dubbed an 'entry' or a
'phrase') with the following fieldnames:

    sk          (subject key)
    st          (subject type)
    sv          (subject value)

    pk          (predicate (key))
    pi          (index (or predicate value))

    ok          (object key)
    ot          (object type)
    ov          (object value)

The value fields—`sv` and `ov`—are special because they have to accommodate various data types. The default
data type is `text` (implemented as `solr.StrField`) and is left unmarked. Values of other data types
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

So in order to store, say, a strokecount, field `ov.i` (object integer value) must be used, and the `ot`
field be set to `i`.


## Comparison with Related Technologies


### Relationship to Graph Databases

A few years ago, a new breed—Graph databases—cropped upped in the data management landscape. Graph DBs
typically have two distinct kinds of objects: nodes and edges. Nodes are used to represent the entities in
your knowledge domain, and edges represent the relationships between entities. It is easy to see that
they are closely related to the EAV model—Es and Vs (our subjects and objects) get reified as nodes, and the
As (our predicates) are turned into edges.

As a matter of fact, an earlier incarnation of MojiKura closely followed this model. The reason why i
abandandoned it in favor of the present model (which in the past i had implemented in Python on top of
PostgreSQL, by the way) is the conceived number of extra documents (entries) one needs to render each part
of a relationship as an entry in its own, and the lack of a formal measure that would help in deciding
whether to store a bit of knowledge directly in the Lucene document that represents an entity, or as a
dedicated relationship with an edge and a target node. Also, in order to get a single fact out of the DB,
one has to bring three entities together, thereby complicating queries.

Of course, it makes sense to not use Lucene or another DB when you're doing graphs and there are graph
databases available, right? Well, maybe not. The field is quite young; there are actually not many
implementations around, few of them open source. The pitches that advertise Graph DBs and the philosophies
behind them often bring the 2000's dot-com crash to mind. The people that write and talk about Graph DBs are
always the same few known ones—there's little in the way of a growing community. The claims (billions of
nodes and relationships traversed in the fraction of a second!) are fantastic, but the sample datasets i've
seen border on the pathetic. The only dataset in the field with significantly more nodes than affords to
express "Alice likes Bob, and Bob is a friend of Carl" that i got to see is a network of relationships of
the characters appearing in Victor Hugo's *Les Misérables*—and that's the one data set they all seem to
love and recycle, producing sometimes ugly, sometimes beautiful graphical display of unknown utilitarian
value. I mean, c'mon guys, even MS Access has a Northwind database.

To sum up, i'm not saying that GraphDBs are snake oil, but they certainly feel a lot like it. Meanwhile, i'm
back to good ol' trusty Lucene, for with all the mindblowing complexity this database does not hide under
its hood, it's being widely used, free, open source, rather performant, and, when need be, i can also do
full text search with it! (MojiKura currently does not, but you can easily configure it to do so). Fact is,
when you want to have full text search in a database, chances are that whatever buzzword product you
choose—GraphDB, Key/Value, NoSQL—its advanced search method will likely be provided by some Lucene Java
classes. You might just as well opt for Lucene in the first place.


### Relationship to Resource Description Framework (RDF)

The MojiKura PhraseDB does have striking similarities to the [Resource Description Framework
(RDF)](http://en.wikipedia.org/wiki/Resource_Description_Framework), a W3C-codified standard that grew out
of the [Semantic Web](http://en.wikipedia.org/wiki/Semantic_Web) movement which was has its heyday in the
late nineties to early two thousands. For example, 'triples' (data entities made up of subject, verb, and
object) feature as prominently in the RDF world as they do in MojiKura.

That said, the PhraseDB concept expressily does *not* come with the hype and hifaluting expectations that
used to surround discussions, applications and schemas which used to come out of the Semantic Web movement.
[As Wikipedia quite rightly quotes](http://en.wikipedia.org/wiki/Semantic_Web): 'Berners-Lee and colleagues
stated that: "This simple idea [i.e. the Semantic Web] ... remains largely unrealized."'

As i experienced it at the time, being 'semantic'
for some reason entailed to produce lots of deeply nested XML<sup>1</sup> tags with lots and lots of
strings-that-look-like-but-are-not-real-URLs. Somehow, back then many people seem to have thought that if
you just nest those pointy brackets deep enough and use URLish `words://separated/by/slashes`, then 'meaning'
would at some point in time just jump out of the box—a veritable *deus ex machina* cargo cult, the
URL being its tin god.<sup>2</sup> The Millennium hype!

> <sup>1</sup>) few recent software technologies have managed to produce more hot air only to get largely
> dumped on the wayside than XML

> <sup>2</sup>) URLs are a terriffic invention—relatively short, ideally memorable strings that have
> gained a global and unique interpretation–but so are ISBNs and EANs, and jotting down 2013-09-22. Is that
> more 'semantic' than it used to be just because more people and more equipment agree on the interpretation
> of these writing marks?—I doubt that.











 -->