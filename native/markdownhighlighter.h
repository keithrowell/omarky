#pragma once

#include <QColor>
#include <QFont>
#include <QPointer>
#include <QQuickTextDocument>
#include <QHash>
#include <QSet>
#include <QTextBlockFormat>
#include <QSyntaxHighlighter>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

#ifdef OMARKY_SONNET
#include <Sonnet/Speller>
#endif

// Byword-style live Markdown for the editor's TextEdit. The source stays
// plain text; this only paints it: syntax marks fade back, emphasis, code,
// links and headings take their look, misspelt words get a wavy line, and
// focus mode fades every paragraph but the one being written.
//
// It also sets each line's block format: the line height, and hanging
// indents so heading marks, list markers and quote marks sit in the left
// gutter with the text aligned to the column (docs/decisions/0014).
class MarkdownHighlighter : public QSyntaxHighlighter
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QQuickTextDocument *document READ quickDocument WRITE setQuickDocument NOTIFY documentChanged)
    // Colours and fonts, all at once so a theme switch repaints once:
    //   text strong dim faint ghost accent link code codeBg mark error   (colours)
    //   prose mono (families), size (body px), lineHeight (percent), gutter (px)
    Q_PROPERTY(QVariantMap look READ look WRITE setLook NOTIFY lookChanged)
    Q_PROPERTY(bool focusMode READ focusMode WRITE setFocusMode NOTIFY focusModeChanged)
    Q_PROPERTY(int cursorPosition READ cursorPosition WRITE setCursorPosition NOTIFY cursorPositionChanged)
    Q_PROPERTY(bool spellCheck READ spellCheck WRITE setSpellCheck NOTIFY spellCheckChanged)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(bool spellAvailable READ spellAvailable NOTIFY languageChanged)

public:
    explicit MarkdownHighlighter(QObject *parent = nullptr);

    QQuickTextDocument *quickDocument() const { return m_quickDocument; }
    void setQuickDocument(QQuickTextDocument *doc);
    QVariantMap look() const { return m_look; }
    void setLook(const QVariantMap &look);
    bool focusMode() const { return m_focusMode; }
    void setFocusMode(bool on);
    int cursorPosition() const { return m_cursor; }
    void setCursorPosition(int pos);
    bool spellCheck() const { return m_spellCheck; }
    void setSpellCheck(bool on);
    QString language() const { return m_language; }
    void setLanguage(const QString &lang);
    bool spellAvailable() const;

    // The first and last line of the paragraph around `pos` ([start, end) chars).
    Q_INVOKABLE QVariantMap paragraphAt(int pos) const;
    // Whether `word` is spelt correctly (true when there is no dictionary).
    Q_INVOKABLE bool isCorrect(const QString &word) const;
    Q_INVOKABLE QStringList suggestions(const QString &word) const;
    Q_INVOKABLE void addToDictionary(const QString &word);
    // Replace [start, end) with `text` as one undo step (a TextEdit's
    // remove and insert are two). False when the range is out of bounds.
    Q_INVOKABLE bool replace(int start, int end, const QString &text);

signals:
    void documentChanged();
    void lookChanged();
    void focusModeChanged();
    void cursorPositionChanged();
    void spellCheckChanged();
    void languageChanged();

protected:
    void highlightBlock(const QString &text) override;

private:
    enum Kind { Plain, Heading, List, Quote, Code };
    struct Layout {
        Kind kind = Plain;
        qreal hang = 0;     // width that hangs left of the text column
        qreal indent = 0;   // leading whitespace of a list item, kept inside
    };

    void rebuildFormats();
    QTextCharFormat colour(const QColor &c) const;
    void applyPending();
    void refreshFocus(int oldFirst, int oldLast);
    void blocksAround(int pos, int *first, int *last) const;
    QTextBlockFormat blockFormatFor(const Layout &l) const;
    bool sameLayout(const QTextBlockFormat &a, const QTextBlockFormat &b) const;
    qreal advance(const QString &s, int px, bool mono = false) const;

    QPointer<QQuickTextDocument> m_quickDocument;
    QVariantMap m_look;
    bool m_focusMode = false;
    int m_cursor = 0;
    int m_cursorBlock = -1;
    int m_focusFirst = -1;
    int m_focusLast = -1;
    bool m_spellCheck = true;
    QString m_language = QStringLiteral("en_AU");

    // Resolved look.
    QColor m_text, m_strong, m_dim, m_faint, m_ghost, m_accent, m_link, m_code, m_codeBg, m_mark, m_error;
    QString m_prose, m_mono;
    int m_size = 18;
    qreal m_lineHeight = 160;
    qreal m_gutter = 64;

    QHash<int, QTextBlockFormat> m_wanted;
    bool m_applyQueued = false;
    bool m_applying = false;

#ifdef OMARKY_SONNET
    Sonnet::Speller *m_speller = nullptr;
#endif
};
