# On Reading at Length

Most of what we read on a screen was never meant to be read slowly. It was meant to be scanned,
skimmed, triaged and dismissed: the notification, the status line, the diff summary, the chat
message that wants an answer before it has finished arriving. The screen trains us to glance.
And then, a few times a day, it hands us something that deserves more than a glance, a design
document or a long argument or a careful plan, and we meet it with the same restless eye.

This essay is about that second kind of reading, and about what a tool can do to make room for it.
It is not about speed. Nobody needs to read a specification faster. The goal is to read it
*once*, properly, and come away knowing what it said.

## The page as an instrument

A printed page is an instrument with a long history of tuning. Its margins, its measure, the gap
between its lines and the weight of its type were not chosen for beauty alone; they were adjusted,
over centuries, until reading stopped being work. When a book is set well, you do not notice the
setting. You notice only that an hour has passed.

Screens threw much of that away, not out of malice but out of indifference. Text was poured into
whatever container happened to be on hand. A line ran as wide as the window. Paragraphs were
separated by a blank line because that was what the markup produced. Headings were big because
big meant important. Every one of these defaults is defensible on its own, and together they make
reading harder than it needs to be.

The good news is that almost none of it is difficult to fix. The fixes are old and well known.
They simply have to be applied with care, one decision at a time, and then left alone.

### Measure

The single most important number on a page is its measure: how many characters sit on one line.
Too short, and the eye is forever jumping back to the left edge, breaking phrases into fragments.
Too long, and the return journey becomes a small act of navigation; you finish a line and hunt
for the start of the next, sometimes landing on the wrong one.

Typographers have argued about the ideal for a long time, and the arguments mostly converge on a
range between forty-five and seventy-five characters, with sixty-six often quoted as the sweet
spot. The exact figure matters less than the principle, which is that the measure should be
*chosen*. It should come from the size of the type, not from the size of the window.

That is why a good reader centres its text in a column and lets the window grow around it. The
extra space is not wasted. It is the margin, and the margin is doing its job: it frames the text,
rests the eye, and tells you where the reading begins.

### Leading

The second number is the distance from one line to the next. Set lines too close and the
ascenders of one row tangle with the descenders of the row above; the text turns grey and dense.
Set them too far apart and each line floats alone, and the paragraph falls to pieces.

For body text at reading sizes, something around one and a half times the type size works for
most faces. Faces with a large x-height want a little more. Longer lines want a little more too,
because the eye needs a clearer track to follow on the way back.

### Rhythm

Beyond the two numbers there is rhythm: the pattern of space between paragraphs, before and after
headings, around quotations and lists and code. Rhythm is where most screen typography quietly
fails, because each element is spaced on its own terms and nobody looks at how they meet.

A heading should sit closer to the text it introduces than to the text it follows. It belongs to
what comes next. A quotation should step away from the body just far enough to be heard as another
voice. A code block should feel like an exhibit placed on the page, not a hole cut through it.

> Good typography is invisible. Bad typography is everywhere, and it is invisible too, which is
> exactly the problem: we have stopped noticing what it costs us.

None of these rules is absolute, and none of them needs to be applied with a ruler. They need to
be applied with an eye, and checked again with the eye, until the page reads the way a page
should.

## Reading documents written by machines

A growing share of what many of us read is written, at least in its first draft, by software.
Agents write plans, decisions, research notes and summaries. They write a great deal of them,
quickly, and they write them in Markdown, because Markdown is what they were trained on and what
the tools around them expect.

This changes the reading problem in a few interesting ways.

First, there is simply more to read. When a plan used to take an afternoon to write, it was
natural to read it carefully. When it takes a minute, the temptation is to skim it just as fast,
and skimming a plan is how the wrong thing gets built.

Second, machine-written documents are structurally rich. They lean on headings, lists, tables,
code blocks and call-outs, often all in one file. A reader that renders only paragraphs well will
render most of these documents badly. The structure is part of the message, and it has to look
like structure.

Third, these documents change while you read them. An agent revises its plan; a spec is updated in
place; a note gains a new section. A reader that notices the change and keeps your place, without
a flash and without losing the paragraph you were on, turns a jarring interruption into something
closer to watching a colleague edit a page on the desk beside you.

### What a reader owes the reader

It is worth being plain about what a tool like this is for. It does not edit. It does not
organise files, sync them, publish them or share them. It opens one document and shows it as well
as it can be shown, and then it gets out of the way.

That narrowness is a feature. Every capability a reading tool adds is a capability that competes
for attention with the text. Toolbars, panels, badges and buttons are each a small tax, and the
taxes add up. The best reading tools feel almost empty: a column of text, a quiet margin, and
nothing else unless you ask for it.

What you do ask for should be instant. An outline, to see the shape of a long document and jump
around in it. A find bar, to locate the one paragraph you half remember. A way to copy a passage
as the Markdown it came from, so you can quote it back to the agent that wrote it. Each of these
should appear when called and vanish when dismissed.

## Colour and light

The last dimension is colour, and here a desktop reader has an advantage a printed book never had:
it can match its surroundings. If your desktop is dark and warm, the page can be dark and warm. If
you switch to a light theme at sunrise, the page can follow without being asked.

Matching the theme is not only a matter of swapping the background. Every tier of emphasis has to
move with it: the body text, the dimmer text of a quotation, the fainter text of a caption, the
tint behind a code block, the hairline under a heading. In a dark theme, surfaces rise toward the
light; in a light theme, they sink toward the ink. Get the tiers right and a single set of rules
produces a page that feels native in every theme. Get them wrong and one theme looks crafted while
the next looks like a ransom note.

Syntax colouring is the hardest case. Code in a reader should look like code in the reader's own
editor, which means drawing its colours from the same palette as everything else, not from a
separate scheme bolted on from elsewhere.

## A small conclusion

There is nothing new in any of this. The measure, the leading, the rhythm and the colour were all
worked out long ago, by people who cared about reading more than most of us ever will. The only
new thing is the volume of text now arriving on our screens, and the growing share of it that
deserves to be read properly.

A good reader is a small act of respect for that text and for the person reading it. It says:
this is worth your full attention, and here is a page that will not waste it.
