#include "markdownhighlighter.h"

#include <QFontDatabase>
#include <QFontMetricsF>
#include <QRegularExpression>
#include <QTextBlock>
#include <QTextCursor>
#include <QTextDocument>
#include <QTimer>

#include <QtGui/private/qtextdocument_p.h>

namespace {

// Layout is presentation, not an edit: it must never become an undo step,
// or Ctrl+Z would undo it, the highlighter would set it again, and undo
// would never get past it. QTextDocument can only switch undo off by
// clearing the history, so this reaches the private flag instead, through
// the explicit-instantiation rule (access isn't checked there), without
// touching anything else private (docs/decisions/0002).
struct UndoFlag { using type = bool QTextDocumentPrivate::*; friend type undoFlag(UndoFlag); };
template <typename Tag, typename Tag::type Member>
struct Expose { friend typename Tag::type undoFlag(Tag) { return Member; } };
template struct Expose<UndoFlag, &QTextDocumentPrivate::undoEnabled>;

// Block states carried from line to line.
enum State { Normal = 0, FrontMatter = 1, Comment = 2, FenceTick = 100, FenceTilde = 200 };

const QRegularExpression &re(const char *pattern)
{
    // One compiled expression per pattern, for the life of the process.
    static QHash<const char *, QRegularExpression *> cache;
    auto it = cache.find(pattern);
    if (it == cache.end())
        it = cache.insert(pattern, new QRegularExpression(QString::fromUtf8(pattern),
                                                          QRegularExpression::UseUnicodePropertiesOption));
    return **it;
}

const char *kHeading = "^( {0,3})(#{1,6})([ \\t]+|$)";
const char *kHr = "^ {0,3}([-*_])(?:[ \\t]*\\1){2,}[ \\t]*$";
const char *kList = "^([ \\t]*)([-*+]|\\d{1,9}[.)])([ \\t]+)(\\[[ xX]\\](?:[ \\t]+|$))?";
const char *kQuote = "^((?: {0,3}>[ ]?)+)";
const char *kFence = "^ {0,3}(`{3,}|~{3,})(.*)$";
const char *kTableSep = "^\\s*\\|?\\s*:?-{2,}:?\\s*(\\|\\s*:?-{1,}:?\\s*)+\\|?\\s*$";
const char *kFootDef = "^\\[\\^[^\\]]+\\]:";
const char *kRefDef = "^ {0,3}\\[[^\\]^][^\\]]*\\]:\\s*\\S+.*$";
const char *kSetext = "^ {0,3}(=+|-+)\\s*$";

const char *kCode = "(`+)(?!`)(.+?)(?<!`)\\1(?!`)";
const char *kLink = "(!?)\\[([^\\]\\n]*)\\]\\(([^)\\s]*)(\\s+\"[^\"]*\")?\\)";
const char *kRefLink = "(!?)\\[([^\\]\\n]+)\\]\\[([^\\]\\n]*)\\]";
const char *kAutolink = "<((?:https?|ftp)://[^>\\s]+|mailto:[^>\\s]+)>";
const char *kBareUrl = "(?<![(<\\w/])((?:https?://|www\\.)[^\\s<>()]+[^\\s<>().,;:!?'\"])";
const char *kBold = "(\\*\\*|__)(?=\\S)(.+?)(?<=\\S)\\1";
const char *kItalicStar = "(?<![*\\\\])\\*(?![*\\s])(.+?)(?<![\\s*\\\\])\\*(?!\\*)";
const char *kItalicUnder = "(?<![\\w_\\\\])_(?![_\\s])(.+?)(?<![\\s_\\\\])_(?![\\w_])";
const char *kStrike = "~~(?=\\S)(.+?)(?<=\\S)~~";
const char *kMark = "==(?=\\S)(.+?)(?<=\\S)==";
const char *kFootRef = "\\[\\^[^\\]\\s]+\\]";
const char *kTag = "</?[A-Za-z][A-Za-z0-9-]*(?:\\s[^<>]*)?/?>";
const char *kEscape = "\\\\[\\\\`*_{}\\[\\]()#+\\-.!|~>=]";
const char *kWord = "\\p{L}[\\p{L}\\p{M}'’]*";

// The style name for a face. Some families (iA Writer Quattro S) give
// every face the same fontconfig weight, so asking for bold by weight finds
// whichever face comes first; naming the style always finds the right one.
QString styleFor(const QString &family, bool bold, bool italic)
{
    static QHash<QString, QString> cache;
    const QString key = family + QLatin1Char('|') + QLatin1Char(bold ? 'b' : '-') + QLatin1Char(italic ? 'i' : '-');
    auto it = cache.constFind(key);
    if (it != cache.constEnd())
        return *it;
    QStringList want;
    if (bold && italic)
        want = {"Bold Italic", "BoldItalic", "Bold Oblique", "Bold"};
    else if (bold)
        want = {"Bold", "Semibold", "SemiBold"};
    else if (italic)
        want = {"Italic", "Oblique", "Regular Italic"};
    else
        want = {"Regular", "Book", "Normal", "Roman"};
    const QStringList have = QFontDatabase::styles(family);
    QString found;
    for (const QString &w : want)
        for (const QString &h : have)
            if (found.isEmpty() && h.compare(w, Qt::CaseInsensitive) == 0)
                found = h;
    cache.insert(key, found);
    return found;
}

QColor colourOf(const QVariantMap &m, const char *key, const QColor &fallback)
{
    QColor c(m.value(QString::fromLatin1(key)).toString());
    return c.isValid() ? c : fallback;
}

} // namespace

MarkdownHighlighter::MarkdownHighlighter(QObject *parent)
    : QSyntaxHighlighter(parent)
{
    rebuildFormats();
}

void MarkdownHighlighter::setQuickDocument(QQuickTextDocument *doc)
{
    if (m_quickDocument == doc)
        return;
    m_quickDocument = doc;
    setDocument(doc ? doc->textDocument() : nullptr);
    emit documentChanged();
}

void MarkdownHighlighter::setLook(const QVariantMap &look)
{
    if (m_look == look)
        return;
    m_look = look;
    rebuildFormats();
    emit lookChanged();
    rehighlight();
}

void MarkdownHighlighter::rebuildFormats()
{
    const QVariantMap &m = m_look;
    m_text = colourOf(m, "text", QColor("#d0d0d0"));
    m_strong = colourOf(m, "strong", m_text);
    m_dim = colourOf(m, "dim", m_text);
    m_faint = colourOf(m, "faint", m_dim);
    m_ghost = colourOf(m, "ghost", m_faint);
    m_accent = colourOf(m, "accent", m_text);
    m_link = colourOf(m, "link", m_accent);
    m_code = colourOf(m, "code", m_text);
    m_codeBg = colourOf(m, "codeBg", QColor(Qt::transparent));
    m_mark = colourOf(m, "mark", m_accent);
    m_error = colourOf(m, "error", QColor("#e06c75"));
    m_prose = m.value("prose", QStringLiteral("iA Writer Duospace")).toString();
    m_mono = m.value("mono", QStringLiteral("iA Writer Mono S")).toString();
    m_size = qMax(8, m.value("size", 18).toInt());
    m_lineHeight = m.value("lineHeight", 160).toReal();
    m_gutter = m.value("gutter", m_size * 3.5).toReal();
}

QTextCharFormat MarkdownHighlighter::colour(const QColor &c) const
{
    QTextCharFormat f;
    f.setForeground(c);
    return f;
}

qreal MarkdownHighlighter::advance(const QString &s, int px, bool mono) const
{
    QFont f(mono ? m_mono : m_prose);
    f.setPixelSize(px);
    return QFontMetricsF(f).horizontalAdvance(s);
}

void MarkdownHighlighter::setFocusMode(bool on)
{
    if (m_focusMode == on)
        return;
    m_focusMode = on;
    blocksAround(m_cursor, &m_focusFirst, &m_focusLast);
    emit focusModeChanged();
    rehighlight();
}

void MarkdownHighlighter::setCursorPosition(int pos)
{
    if (m_cursor == pos)
        return;
    m_cursor = pos;
    emit cursorPositionChanged();
    QTextDocument *doc = document();
    if (!doc || m_applying)
        return;
    const int block = doc->findBlock(pos).blockNumber();
    const int oldBlock = m_cursorBlock;
    m_cursorBlock = block;
    // The word being typed is left alone by the spell checker until the
    // cursor leaves it, so the line it was on is repainted then.
    if (m_spellCheck && oldBlock != block && oldBlock >= 0) {
        QTextBlock b = doc->findBlockByNumber(oldBlock);
        if (b.isValid())
            rehighlightBlock(b);
    }
    if (m_focusMode) {
        const int oldFirst = m_focusFirst, oldLast = m_focusLast;
        blocksAround(pos, &m_focusFirst, &m_focusLast);
        if (oldFirst != m_focusFirst || oldLast != m_focusLast)
            refreshFocus(oldFirst, oldLast);
    }
}

void MarkdownHighlighter::refreshFocus(int oldFirst, int oldLast)
{
    QTextDocument *doc = document();
    if (!doc)
        return;
    QSet<int> touched;
    for (int i = oldFirst; i >= 0 && i <= oldLast; ++i)
        touched.insert(i);
    for (int i = m_focusFirst; i >= 0 && i <= m_focusLast; ++i)
        touched.insert(i);
    for (int n : touched) {
        QTextBlock b = doc->findBlockByNumber(n);
        if (b.isValid())
            rehighlightBlock(b);
    }
}

// A paragraph: the run of non-blank lines around the cursor's line.
void MarkdownHighlighter::blocksAround(int pos, int *first, int *last) const
{
    QTextDocument *doc = document();
    if (!doc) {
        *first = *last = -1;
        return;
    }
    QTextBlock b = doc->findBlock(pos);
    if (!b.isValid()) {
        *first = *last = -1;
        return;
    }
    QTextBlock up = b, down = b;
    if (!b.text().trimmed().isEmpty()) {
        while (up.previous().isValid() && !up.previous().text().trimmed().isEmpty())
            up = up.previous();
        while (down.next().isValid() && !down.next().text().trimmed().isEmpty())
            down = down.next();
    }
    *first = up.blockNumber();
    *last = down.blockNumber();
}

QVariantMap MarkdownHighlighter::paragraphAt(int pos) const
{
    int first = -1, last = -1;
    blocksAround(pos, &first, &last);
    QVariantMap r;
    QTextDocument *doc = document();
    if (!doc || first < 0)
        return r;
    QTextBlock a = doc->findBlockByNumber(first), z = doc->findBlockByNumber(last);
    r["start"] = a.position();
    r["end"] = z.position() + z.length() - 1;
    return r;
}

void MarkdownHighlighter::setSpellCheck(bool on)
{
    if (m_spellCheck == on)
        return;
    m_spellCheck = on;
    emit spellCheckChanged();
    rehighlight();
}

void MarkdownHighlighter::setLanguage(const QString &lang)
{
    if (m_language == lang)
        return;
    m_language = lang;
#ifdef OMAWRITER_SONNET
    if (m_speller)
        m_speller->setLanguage(lang);
#endif
    emit languageChanged();
    rehighlight();
}

bool MarkdownHighlighter::spellAvailable() const
{
#ifdef OMAWRITER_SONNET
    if (!m_speller) {
        auto *self = const_cast<MarkdownHighlighter *>(this);
        self->m_speller = new Sonnet::Speller(m_language);
    }
    return m_speller->isValid();
#else
    return false;
#endif
}

bool MarkdownHighlighter::isCorrect(const QString &word) const
{
#ifdef OMAWRITER_SONNET
    if (!spellAvailable())
        return true;
    return m_speller->isCorrect(word);
#else
    Q_UNUSED(word);
    return true;
#endif
}

QStringList MarkdownHighlighter::suggestions(const QString &word) const
{
#ifdef OMAWRITER_SONNET
    if (!spellAvailable())
        return {};
    return m_speller->suggest(word).mid(0, 6);
#else
    Q_UNUSED(word);
    return {};
#endif
}

void MarkdownHighlighter::addToDictionary(const QString &word)
{
#ifdef OMAWRITER_SONNET
    if (spellAvailable())
        m_speller->addToPersonal(word);
    rehighlight();
#else
    Q_UNUSED(word);
#endif
}

QTextBlockFormat MarkdownHighlighter::blockFormatFor(const Layout &l) const
{
    QTextBlockFormat f;
    f.setLineHeight(m_lineHeight, QTextBlockFormat::ProportionalHeight);
    // Hanging marks: the line starts `hang` left of the column, so its mark
    // sits in the gutter and wrapped lines align with the text.
    f.setLeftMargin(m_gutter + l.indent);
    f.setTextIndent(-qMin(l.hang, m_gutter + l.indent));
    return f;
}

bool MarkdownHighlighter::sameLayout(const QTextBlockFormat &a, const QTextBlockFormat &b) const
{
    return a.lineHeightType() == b.lineHeightType() && qFuzzyCompare(a.lineHeight() + 1, b.lineHeight() + 1)
        && qAbs(a.leftMargin() - b.leftMargin()) < 0.5 && qAbs(a.textIndent() - b.textIndent()) < 0.5;
}

// Block formats can't be set from inside highlightBlock, so changed lines
// are queued and set right after, outside the undo history.
void MarkdownHighlighter::applyPending()
{
    m_applyQueued = false;
    QTextDocument *doc = document();
    if (!doc || m_wanted.isEmpty())
        return;
    QList<int> blocks = m_wanted.keys();
    std::sort(blocks.begin(), blocks.end());

    QList<QPair<QTextBlock, QTextBlockFormat>> work;
    for (int n : blocks) {
        QTextBlock b = doc->findBlockByNumber(n);
        if (!b.isValid())
            continue;
        // The wanted format was stashed when the line was painted.
        const QTextBlockFormat f = m_wanted.value(n);
        if (!f.isValid() || sameLayout(b.blockFormat(), f))
            continue;
        work.append({b, f});
    }
    m_wanted.clear();
    if (work.isEmpty())
        return;

    m_applying = true;
    bool &undo = QTextDocumentPrivate::get(doc)->*undoFlag(UndoFlag());
    const bool wasUndo = undo;
    undo = false;
    QTextCursor c(doc);
    c.beginEditBlock();
    for (auto &w : work) {
        c.setPosition(w.first.position());
        QTextBlockFormat f = w.first.blockFormat();
        f.merge(w.second);
        c.setBlockFormat(f);
    }
    c.endEditBlock();
    undo = wasUndo;
    m_applying = false;
}

void MarkdownHighlighter::highlightBlock(const QString &text)
{
    const int n = text.size();
    const int prev = qMax(0, previousBlockState());
    const QTextBlock block = currentBlock();
    const int blockNo = block.blockNumber();
    setCurrentBlockState(Normal);

    QTextCharFormat base;
    base.setFontFamilies({m_prose});
    base.setProperty(QTextFormat::FontPixelSize, m_size);
    base.setFontWeight(QFont::Normal);
    base.setFontItalic(false);
    base.setForeground(m_text);

    QVector<QTextCharFormat> f(n, base);
    QVector<bool> literal(n, false);   // no inline syntax inside (code, URLs)
    QVector<bool> spell(n, true);      // words here are spell checked
    Layout layout;

    auto merge = [&](int start, int len, const QTextCharFormat &fmt) {
        for (int i = qMax(0, start); i < qMin(n, start + len); ++i)
            f[i].merge(fmt);
    };
    auto lit = [&](int start, int len) {
        for (int i = qMax(0, start); i < qMin(n, start + len); ++i) {
            literal[i] = true;
            spell[i] = false;
        }
    };
    auto free = [&](int start, int len) {
        for (int i = qMax(0, start); i < qMin(n, start + len); ++i)
            if (literal[i])
                return false;
        return true;
    };

    QTextCharFormat faint = colour(m_faint);
    QTextCharFormat monoCode;
    monoCode.setFontFamilies({m_mono});
    monoCode.setProperty(QTextFormat::FontPixelSize, qRound(m_size * 0.88));
    monoCode.setForeground(m_code);

    int inlineStart = 0;   // where inline parsing begins on this line
    bool doInline = true;

    auto codeLine = [&]() {
        merge(0, n, monoCode);
        lit(0, n);
        doInline = false;
        layout.kind = Code;
    };

    QRegularExpressionMatch m;
    // ---- lines inside multi-line constructs
    if (prev >= FenceTick) {
        const int fenceLen = prev % 100;
        const QChar fenceChar = prev >= FenceTilde ? QLatin1Char('~') : QLatin1Char('`');
        m = re(kFence).match(text);
        if (m.hasMatch() && m.captured(1).at(0) == fenceChar && m.captured(1).size() >= fenceLen
            && m.captured(2).trimmed().isEmpty()) {
            merge(0, n, monoCode);
            merge(0, n, faint);
            lit(0, n);
            doInline = false;
            layout.kind = Code;
        } else {
            codeLine();
            setCurrentBlockState(prev);
        }
    } else if (prev == FrontMatter) {
        merge(0, n, monoCode);
        lit(0, n);
        doInline = false;
        if (text == QLatin1String("---") || text == QLatin1String("...")) {
            merge(0, n, faint);
        } else {
            setCurrentBlockState(FrontMatter);
            const int colon = text.indexOf(QLatin1Char(':'));
            merge(0, n, colour(m_dim));
            if (colon > 0)
                merge(0, colon + 1, colour(m_mark));
        }
    } else if (prev == Comment) {
        merge(0, n, faint);
        lit(0, n);
        doInline = false;
        if (!text.contains(QLatin1String("-->")))
            setCurrentBlockState(Comment);
    } else if (blockNo == 0 && text == QLatin1String("---")) {
        merge(0, n, monoCode);
        merge(0, n, faint);
        lit(0, n);
        doInline = false;
        setCurrentBlockState(FrontMatter);
    } else if ((m = re(kFence).match(text)).hasMatch() && !(m.captured(1).at(0) == QLatin1Char('`') && m.captured(2).contains(QLatin1Char('`')))) {
        const QString fence = m.captured(1);
        merge(0, n, monoCode);
        merge(0, n, faint);
        lit(0, n);
        doInline = false;
        layout.kind = Code;
        setCurrentBlockState((fence.at(0) == QLatin1Char('~') ? FenceTilde : FenceTick) + qMin(99, (int)fence.size()));
    } else if (text.trimmed().startsWith(QLatin1String("<!--"))) {
        merge(0, n, faint);
        lit(0, n);
        doInline = false;
        if (!text.contains(QLatin1String("-->")))
            setCurrentBlockState(Comment);
    } else if ((m = re(kHeading).match(text)).hasMatch()) {
        const int level = m.captured(2).size();
        static const qreal scale[] = {1, 1.5, 1.28, 1.12, 1.0, 1.0, 1.0};
        const int px = qRound(m_size * scale[level]);
        QTextCharFormat h;
        h.setProperty(QTextFormat::FontPixelSize, px);
        h.setFontWeight(QFont::Bold);
        h.setForeground(m_strong);
        merge(0, n, h);
        const int markEnd = m.capturedEnd(0);
        QTextCharFormat mark = colour(m_faint);
        mark.setFontWeight(QFont::Normal);
        merge(0, markEnd, mark);
        lit(0, markEnd);
        // A closing run of #s is decoration too.
        static const QRegularExpression closing(QStringLiteral("\\s+#+\\s*$"));
        QRegularExpressionMatch cm = closing.match(text, markEnd);
        if (cm.hasMatch()) {
            merge(cm.capturedStart(0), cm.capturedLength(0), mark);
            lit(cm.capturedStart(0), cm.capturedLength(0));
        }
        layout.kind = Heading;
        layout.hang = advance(text.left(markEnd), px);
        inlineStart = markEnd;
    } else if (re(kHr).match(text).hasMatch()) {
        merge(0, n, faint);
        lit(0, n);
        doInline = false;
    } else if (re(kSetext).match(text).hasMatch() && block.previous().isValid()
               && !block.previous().text().trimmed().isEmpty()) {
        merge(0, n, faint);
        lit(0, n);
        doInline = false;
    } else if ((m = re(kQuote).match(text)).hasMatch()) {
        const int markEnd = m.capturedEnd(1);
        QTextCharFormat q;
        q.setForeground(m_dim);
        q.setFontItalic(true);
        merge(markEnd, n - markEnd, q);
        merge(0, markEnd, colour(m_mark));
        lit(0, markEnd);
        layout.kind = Quote;
        layout.hang = advance(text.left(markEnd), m_size);
        inlineStart = markEnd;
        // A list inside a quote keeps the quote's hang.
    } else if ((m = re(kList).match(text)).hasMatch()) {
        const QString lead = m.captured(1);
        const int markerStart = m.capturedStart(2);
        const int markEnd = m.capturedEnd(0);
        QTextCharFormat marker = colour(m_mark);
        merge(markerStart, m.capturedEnd(3) - markerStart, marker);
        if (m.capturedLength(4) > 0) {
            const bool done = m.captured(4).contains(QLatin1Char('x'), Qt::CaseInsensitive);
            QTextCharFormat box = colour(m_mark);
            box.setFontFamilies({m_mono});
            merge(m.capturedStart(4), m.capturedLength(4), box);
            if (done) {
                QTextCharFormat doneText;
                doneText.setForeground(m_faint);
                doneText.setFontStrikeOut(true);
                merge(markEnd, n - markEnd, doneText);
            }
        }
        lit(0, markEnd);
        layout.kind = List;
        const qreal leadW = advance(lead, m_size);
        layout.indent = leadW;
        // The task box belongs to the item's text; only the marker hangs.
        layout.hang = advance(text.left(m.capturedEnd(3)), m_size);
        inlineStart = markEnd;
    } else if (re(kTableSep).match(text).hasMatch()) {
        merge(0, n, faint);
        lit(0, n);
        doInline = false;
    } else if (re(kRefDef).match(text).hasMatch()) {
        merge(0, n, faint);
        lit(0, n);
        doInline = false;
    } else if ((m = re(kFootDef).match(text)).hasMatch()) {
        merge(0, m.capturedEnd(0), colour(m_mark));
        lit(0, m.capturedEnd(0));
        layout.hang = advance(text.left(m.capturedEnd(0)) + QLatin1Char(' '), m_size);
        inlineStart = m.capturedEnd(0);
    }

    // ---- inline syntax
    if (doInline && inlineStart < n) {
        QRegularExpressionMatchIterator it;
        // Escapes: the backslash fades, the character is literal.
        it = re(kEscape).globalMatch(text, inlineStart);
        while (it.hasNext()) {
            auto x = it.next();
            merge(x.capturedStart(), 1, faint);
            lit(x.capturedStart(), 2);
        }
        // Code spans.
        it = re(kCode).globalMatch(text, inlineStart);
        while (it.hasNext()) {
            auto x = it.next();
            if (!free(x.capturedStart(), 1))
                continue;
            QTextCharFormat c = monoCode;
            c.setBackground(m_codeBg);
            merge(x.capturedStart(), x.capturedLength(), c);
            merge(x.capturedStart(1), x.capturedLength(1), faint);
            merge(x.capturedEnd(2), x.capturedLength(1), faint);
            lit(x.capturedStart(), x.capturedLength());
        }
        // Inline HTML tags.
        it = re(kTag).globalMatch(text, inlineStart);
        while (it.hasNext()) {
            auto x = it.next();
            if (!free(x.capturedStart(), x.capturedLength()))
                continue;
            merge(x.capturedStart(), x.capturedLength(), faint);
            lit(x.capturedStart(), x.capturedLength());
        }
        // Links and images: the text in the link colour, the rest faded.
        it = re(kLink).globalMatch(text, inlineStart);
        while (it.hasNext()) {
            auto x = it.next();
            if (!free(x.capturedStart(), 1))
                continue;
            const bool image = x.capturedLength(1) > 0;
            const int textStart = x.capturedStart(2), textLen = x.capturedLength(2);
            QTextCharFormat t;
            t.setForeground(image ? m_dim : m_link);
            if (image)
                t.setFontItalic(true);
            merge(textStart, textLen, t);
            merge(x.capturedStart(), textStart - x.capturedStart(), faint);
            const int tail = x.capturedEnd(2);
            QTextCharFormat url = faint;
            url.setProperty(QTextFormat::FontPixelSize, qRound(m_size * 0.86));
            merge(tail, x.capturedEnd() - tail, url);
            lit(x.capturedStart(), textStart - x.capturedStart());
            lit(tail, x.capturedEnd() - tail);
        }
        it = re(kRefLink).globalMatch(text, inlineStart);
        while (it.hasNext()) {
            auto x = it.next();
            if (!free(x.capturedStart(), 1))
                continue;
            merge(x.capturedStart(2), x.capturedLength(2), colour(m_link));
            merge(x.capturedStart(), x.capturedStart(2) - x.capturedStart(), faint);
            merge(x.capturedEnd(2), x.capturedEnd() - x.capturedEnd(2), faint);
            lit(x.capturedEnd(2), x.capturedEnd() - x.capturedEnd(2));
        }
        it = re(kAutolink).globalMatch(text, inlineStart);
        while (it.hasNext()) {
            auto x = it.next();
            if (!free(x.capturedStart(), x.capturedLength()))
                continue;
            merge(x.capturedStart(), x.capturedLength(), colour(m_link));
            merge(x.capturedStart(), 1, faint);
            merge(x.capturedEnd() - 1, 1, faint);
            lit(x.capturedStart(), x.capturedLength());
        }
        it = re(kBareUrl).globalMatch(text, inlineStart);
        while (it.hasNext()) {
            auto x = it.next();
            if (!free(x.capturedStart(), x.capturedLength()))
                continue;
            merge(x.capturedStart(), x.capturedLength(), colour(m_link));
            lit(x.capturedStart(), x.capturedLength());
        }
        it = re(kFootRef).globalMatch(text, inlineStart);
        while (it.hasNext()) {
            auto x = it.next();
            if (!free(x.capturedStart(), x.capturedLength()))
                continue;
            merge(x.capturedStart(), x.capturedLength(), colour(m_mark));
            lit(x.capturedStart(), x.capturedLength());
        }

        // Emphasis: content styled, the marks faded and set aside so a
        // later, shorter pattern can't reuse them.
        auto emphasis = [&](const char *pattern, int markLen, const QTextCharFormat &style, int group) {
            QRegularExpressionMatchIterator e = re(pattern).globalMatch(text, inlineStart);
            while (e.hasNext()) {
                auto x = e.next();
                const int s = x.capturedStart(), end = x.capturedEnd();
                if (!free(s, markLen) || !free(end - markLen, markLen))
                    continue;
                merge(x.capturedStart(group), x.capturedLength(group), style);
                merge(s, markLen, faint);
                merge(end - markLen, markLen, faint);
                lit(s, markLen);
                lit(end - markLen, markLen);
            }
        };
        QTextCharFormat bold;
        bold.setFontWeight(QFont::Bold);
        bold.setForeground(m_strong);
        QTextCharFormat italic;
        italic.setFontItalic(true);
        QTextCharFormat strike;
        strike.setFontStrikeOut(true);
        strike.setForeground(m_dim);
        QTextCharFormat mark;
        QColor wash = m_accent;
        wash.setAlphaF(0.22f);
        mark.setBackground(wash);
        emphasis(kBold, 2, bold, 2);
        emphasis(kItalicStar, 1, italic, 1);
        emphasis(kItalicUnder, 1, italic, 1);
        emphasis(kStrike, 2, strike, 1);
        emphasis(kMark, 2, mark, 1);

        // Tables: the pipes fade.
        if (text.trimmed().startsWith(QLatin1Char('|'))) {
            for (int i = inlineStart; i < n; ++i)
                if (text.at(i) == QLatin1Char('|') && !literal[i] && (i == 0 || text.at(i - 1) != QLatin1Char('\\')))
                    f[i].merge(faint);
        }
    }

    // ---- spelling
#ifdef OMAWRITER_SONNET
    if (m_spellCheck && doInline && spellAvailable()) {
        const int blockPos = block.position();
        QRegularExpressionMatchIterator w = re(kWord).globalMatch(text, inlineStart);
        while (w.hasNext()) {
            auto x = w.next();
            int s = x.capturedStart(), len = x.capturedLength();
            QString word = x.captured();
            while (len > 0 && (word.endsWith(QLatin1Char('\'')) || word.endsWith(QChar(0x2019)))) {
                word.chop(1);
                --len;
            }
            if (len < 2)
                continue;
            bool ok = true;
            for (int i = s; i < s + len; ++i)
                if (!spell[i]) { ok = false; break; }
            if (!ok)
                continue;
            // Joined to digits, dots or slashes: a name, a file, a version.
            const QChar before = s > 0 ? text.at(s - 1) : QChar();
            const QChar after = s + len < n ? text.at(s + len) : QChar();
            auto joined = [](QChar c) { return c.isDigit() || c == QLatin1Char('_') || c == QLatin1Char('/') || c == QLatin1Char('@'); };
            if (joined(before) || joined(after) || (after == QLatin1Char('.') && s + len + 1 < n && text.at(s + len + 1).isLetter()))
                continue;
            // Acronyms and camelCase are left alone.
            int upper = 0;
            for (QChar c : word)
                if (c.isUpper())
                    ++upper;
            if (upper > 1)
                continue;
            // The word under the cursor is still being typed.
            if (blockPos + s + len == m_cursor || (blockPos + s <= m_cursor && m_cursor <= blockPos + s + len && block.blockNumber() == m_cursorBlock))
                continue;
            if (m_speller->isCorrect(word))
                continue;
            QTextCharFormat e;
            e.setUnderlineStyle(QTextCharFormat::SingleUnderline);
            e.setUnderlineColor(m_error);
            merge(s, len, e);
        }
    }
#endif

    // ---- focus mode: everything but the current paragraph steps back
    if (m_focusMode && m_focusFirst >= 0 && (blockNo < m_focusFirst || blockNo > m_focusLast)) {
        QTextCharFormat away;
        away.setForeground(m_ghost);
        away.setBackground(Qt::transparent);
        away.setUnderlineStyle(QTextCharFormat::NoUnderline);
        for (int i = 0; i < n; ++i)
            f[i].merge(away);
    }

    // ---- faces by name (see styleFor)
    for (int k = 0; k < n; ++k) {
        const QStringList fams = f[k].fontFamilies().toStringList();
        const QString style = styleFor(fams.isEmpty() ? m_prose : fams.first(), f[k].fontWeight() >= QFont::DemiBold, f[k].fontItalic());
        if (!style.isEmpty())
            f[k].setFontStyleName(style);
    }

    // ---- paint, in runs
    int i = 0;
    while (i < n) {
        int j = i + 1;
        while (j < n && f[j] == f[i])
            ++j;
        setFormat(i, j - i, f[i]);
        i = j;
    }

    // ---- this line's layout, applied once painting is done
    if (!m_applying) {
        const QTextBlockFormat want = blockFormatFor(layout);
        if (!sameLayout(block.blockFormat(), want)) {
            m_wanted.insert(blockNo, want);
            if (!m_applyQueued) {
                m_applyQueued = true;
                QTimer::singleShot(0, this, &MarkdownHighlighter::applyPending);
            }
        }
    }
}
