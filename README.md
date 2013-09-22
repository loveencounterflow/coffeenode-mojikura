
![MojiKura](https://github.com/loveencounterflow/coffeenode-mojikura/raw/master/art/mojikura-logo-small.png "MojiKura")


# CoffeeNode MojiKura

## What is it?

<script type="text/javascript" src='https://raw.github.com/threedaymonk/furigana-shim/master/furigana.js'></script>

<ruby>
<rb>文</rb><rp>(</rp><rt>も</rt><rp>)</rp>
<rb>字</rb><rp>(</rp><rt>じ</rt><rp>)</rp>
<rb>倉</rb><rp>(</rp><rt>くら</rt><rp>)</rp>
</ruby>

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
* '業' has the strokeorder 丨丨丶丿一丶丿一一一丨丿丶.
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
"'業' has the strokeorder 丨丨丶丿一丶丿一一一丨丿丶", the predicate is 'has the strokeorder'. Over the years i've
come to prefer structured identifiers that provide a way of rough categorization of things, so instead of
saying just 'has strokeorder', let's call the predicate 'has/shape/strokeorder'. The 'shape' part classifies
strokeorder together with a number of other facts we can tell about the look of a glyph, which may be useful
for queries.

Now for the object. The way i wrote it above, it is '丨丨丶丿一丶丿一一一丨丿丶'; however, for ease of search, i prefer to
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
    subject value:    業

    predicate:        has/shape/strokeorder

    object key:       shape/strokeorder/zhaziwubifa
    object value:     2243143111234

These facets (key / value pairs) are, in essence, what is going to be stored in the database. We can cast
the facets into a single string, somewhat like a Uniform Resource Identifier (as which it will serve in the
DB). I here adopt the convention to separate the parts of speech by ',' (commas) and key / value pairs by ':'
(colons):

    glyph:業,has/shape/strokeorder,shape/strokeorder/zhaziwubifa:2243143111234

That's neat, because what's more general and more capable than a line of text? One can imagine that a backup
of a phrasal DB can simply consist in a textfile, with each line representing one record.

The astute reader may wonder why we go through the trouble to key the predicate as `has/shape/strokeorder`
and the object as `shape/strokeorder/zhaziwubifa`, which looks rather redundant. The redundancy, however, is
by no means to be found in all phrases; for example, in the statement

* '業' has '业' as its component

'業' is the subject and '业' the object—both of them glyphs, so the phrase for this fact may be written out as

    glyph:業,has/shape/component,glyph:业

which establishes a relationship between two glyphs. The names used here are of course just suggestions;
you could just as well use single words or arbitrary strings, but i like to keep things readable.

There are two slight complications we still have to deal with: for one thing, there might be several phrases
that share a common subject and predicate, but have different values—in the examples given above, that
observation readily applies to the readings and the componential analysis. To accommodate for this, we
bluntly stipulate that each phrase shall bear an index which counts all occurrances of a given subject /
predicate pair, and that the index shall be treated as the 'value' of the predicate, as it were. Using
zero-based indices we can then write out the facts about the components of '業' as

    glyph:業,has/shape/component:0,glyph:业
    glyph:業,has/shape/component:1,glyph:𦍎

Secondly, there will be object values we do not want to store as texts—prices, lengths, truth values, geographic
locations, dates and so forth; there will even be subjects that should not be stored as texts, e.g. when we
want to state what happened in the year 690 CE<sup>4</sup>, we want to store the subject as a date, since
only then can we take advantage of all the date-related features that Lucene offers. The next section states
that dates are associated with the sigil 'd', and integers with 'i'; in order to get the data type sigil
unambiguously into a phrase, we can put it into round brackets and prefix the subject or object key with
it. Here are two of the seven facts the English Wikipedia has recorded about the year 690, and one meta-fact:

    (d)year:690,politics/china/emperor/investiture:0,person:wuzetian
    (d)year:690,culture/china/character/created:0,glyph:曌
    (d)year:690,en.wikipedia/trivia/count:0,(i)trivia/count:7

> <sup>4</sup>) trivia: [the character '曌' was created](http://en.wikipedia.org/wiki/Chinese_characters_of_Empress_Wu),
> and [Empress Dowager Wu Zetian ascended the throne](http://en.wikipedia.org/wiki/Wu_Zetian).

We still have to specify which fields have to be set to which values using our generalized schema.
In anticipitation of the field names as listed in [Database Structure and Field Names](#database-structure-and-field-names),
below, we add two optional fields `st` (for subject type) and `ot` (for object type); these are text values
themselves and destined to hold the respective data type sigil whenever the data type is anything but a plain
text. Next, we cannot use the fields `sv` and `ov`, since Lucene only stores one particular data type in
one particular field; instead, we use the value field name (`sv` or `ov`) suffixed with a period and the
data type sigil (giving us e.g. `sv.d` for a date subject value and `ov.i` for an integer object value):

    (d)year:690,politics/china/emperor/investiture:0,person:wuzetian

    sk:       year
    st:       d
    sv.d:     690
    p:        politics/china/emperor/investiture
    i:        0
    ok:       person
    ov:       wuzetian


    (d)year:690,en.wikipedia/trivia/count:0,(i)trivia/count:7

    sk:       year
    st:       d
    sv.d:     690
    p:        en.wikipedia/trivia/count
    i:        0
    ok:       trivia/count
    ot:       i
    ov.i:     7




## IDs and Meta-Phrases

In databases, it's always nice (and, in the case of Lucene, always necessary) to associate each record with
a unique ID. We have seen above that each entry in the MojiKura Phrasal DB can be unambiguously turned into
a URL-like phrase, and vice-versa. Conceivably, we could then go and stipulate that the ID of an entry
shall be its phrase, which is straightforward. However, i prefer to go a step further and use a hash of the
entry phrase instead of the phrase itself; that way, we avoid to repeat potentially long strings just for the
ID, and we gain the ability to form meta-phrases with less hassle.

For the hash, i'm currently using the first 12 characters of the hexadecimal representation of the
SHA-256 cryptographic digest of the entry phrase. The choice of the algorithm and hash length is rather
arbitrary; in the future, the algorithm will likely be substituted by a non-cryptographic hash, which is
potentially faster without sacrificing the important properties of a hash, namely, to uniquely identify texts
with a low probability of a hash collision.

Why does a hash ID help in formulating meta-phrases?—Consider the phrase about '曌' from above:

    (d)year:690,culture/china/character/created:0,glyph:曌

Imagine we want to state that the source of this fact is a certain article on Wikipedia:

    x,has/source:0,(URL)web:http://en.wikipedia.org/wiki/Wu_Zetian

what piece of data should we use to identify the subject of that phrase? The subject is itself an entry
in the database, so it would be natural to use its ID. If, however, we used phrases as IDs, we would get
something like

    phrase:"(d)year:690,culture/china/character/created:0,glyph:曌",has/source:0,(URL)web:http://en.wikipedia.org/wiki/Wu_Zetian

which is unwieldy to say the least. It doesn't scale, either. A Wikipedia page can change anytime, so maybe
we want to add a meta-phrase to that meta-phrase

    x,as/read/on:0,(d)date/2013-09-22

which turns out to be rather convoluted when written out:

    phrase:"phrase:\"(d)year:690,culture/china/character/created:0,glyph:曌\",has/source:0,(URL)web:http://en.wikipedia.org/wiki/Wu_Zetian",as/read/on:0,(d)date/2013-09-22

You can probably see where this is going. Now, given that in the current scheme the ID of the first phrase,
above, is `33ae6c611032` and the data type sigil for phrase IDs is 'm', we can rewrite the first meta-phrase
as

    (m)phrase:33ae6c611032,has/source:0,(URL)web:http://en.wikipedia.org/wiki/Wu_Zetian

Now the ID of *this* phrase is computed as `4ae2f0bfbc27`, so our meta-meta-phrase becomes simply

    (m)phrase:4ae2f0bfbc27,as/read/on:0,(d)date/2013-09-22

Hashes as IDs, then, allow us to formulate meta-phrases as succinctly as ordinary, non-meta phrases—both
kinds actually look identical.


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

    (m)phrase:2a82f9bcbc27,added:0,(d)date/2013-11-11
    (m)phrase:2a82f9bcbc27,addid:1,(d)date/2013-11-12

How many errors can you spot? There are (probably) three: One, it makes little sense to record two different
times a given fact has entered the database (note the identical subject IDs). Two, there's
(probably) a spelling error in the second phrase. Three, the index of the second phrase is (probably) bogus,
assuming there is no phrase matching `(m)phrase:2a82f9bcbc27,addid:0,*`. That's because, as it stands,
MojiKura does not check keys, values or indices—that's your job.

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
not match this definition is open to contention.<sup>5</sup> This means that in order to check for real data
integrity, we need a lot of domain-specific knowledge—far beyond the reach of the static types you'll find
in typical RDBMSes or static programming languages.

> <sup>5</sup>) In my book, that does not really cover most characters in Unicode blocks like the [Kangxi Radicals](http://en.wikipedia.org/wiki/Radical_%28Chinese_characters%29#Unicode)
> and the [compatibility characters](http://en.wikipedia.org/wiki/Unicode_compatibility_characters#Compatibility_Blocks).

Likewise, while i can imagine there is something to say in favor of having MojiKura check for sane indexes
on phrases, nothing short of a full-blown programming language is powerful enough to check for more
'interesting' higher-order potential sources of data integrity failures. For instance, consider that in
order to be consistent, phrases like

    glyph:業,has/shape/strokeorder,shape/strokeorder/zhaziwubifa:2243143111234
    glyph:業:has/shape/strokecount#0:(i)shape/strokecount:13

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

    p           (predicate)
    idx         (index)

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


## Relationship to Graph Databases

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







