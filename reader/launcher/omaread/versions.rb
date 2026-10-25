module OmaRead
  # The JSON the window asks the launcher for: one resolved side of a
  # comparison (--resolve), or the file's history and shortcuts (--versions).
  # The window keeps the two sides itself; nothing is written to disk.
  module Versions
    module_function

    # One side of a comparison: the version's display fields plus its text.
    def side(history, resolver, v, now_text)
      return now_side(now_text) if v == :now
      d = resolver.display(v)
      d.merge("label" => d["who"], "text" => history.text_at(v.sha) || "")
    end

    def now_side(text) = { "label" => "Now", "who" => "Now", "text" => text }

    # The version list for the window. `dirty` says the file on disk differs
    # from its newest check-in, so "Now" is a version of its own.
    def summary(history, resolver)
      return { "inRepo" => false, "dirty" => false, "history" => [], "shortcuts" => [] } unless history.in_repo?
      versions = history.versions
      dirty = !versions.empty? && history.text_at(versions.first.sha) != history.disk_text
      { "inRepo" => true, "dirty" => dirty,
        "history" => versions.map { resolver.display(_1) },
        "shortcuts" => resolver.shortcuts, "me" => history.user_name }
    end
  end
end
