# Alerts

GitHub's alert syntax turns a blockquote into a call-out. OmarkyReader draws each kind as a tinted card
in the matching theme colour, with an icon and a small mono title.

> [!NOTE]
> Useful information that users should know, even when skimming content.

> [!TIP]
> Helpful advice for doing things better or more easily. Tips can run to several sentences, and
> they wrap inside the card just like a paragraph does, with the same measure and line height.

> [!IMPORTANT]
> Key information users need to know to achieve their goal.
>
> - It can hold a list,
> - or `inline code`,
> - or anything else a quote can hold.

> [!WARNING]
> Urgent info that needs immediate user attention to avoid problems.

> [!CAUTION]
> Advises about risks or negative outcomes of certain actions.
>
> ```bash
> rm -rf ~/.local/state/omarchy/current/theme   # never do this by hand
> ```

## Not alerts

> [!UNKNOWN]
> An unknown kind stays an ordinary blockquote.

> A normal quote, for comparison. It has an accent bar and slightly dimmer text.

> [!NOTE] Text on the same line as the marker keeps GitHub's behaviour: this is a plain quote.
