module OmaRead
  class Unresolved < StandardError; end

  # Turns a spec ("danny", "yesterday", "before danny fri", "sent", "before
  # now", a ref) into a Version of the file, or :now.
  class Resolver
    DAYS = %w[sunday monday tuesday wednesday thursday friday saturday]
    MONTHS = %w[january february march april may june july august september october november december]
    NAME = /\A[[:alpha:]'\-]+\z/

    def initialize(history, now: Time.now)
      @h = history
      @now = now
    end

    def resolve(spec, before: nil)
      s = spec.to_s.strip.downcase
      return :now if s.empty? || s == "now"
      return resolve_before(s.sub(/\Abefore\s+/, ""), before) if s.start_with?("before ")
      return resolve_sent(before) if s == "sent"

      words = s.split(/\s+/)
      person, day_words = split_person(words, spec.to_s.strip)
      day = day_words.empty? ? nil : parse_day(day_words.join(" "))
      if person.nil? && day.nil?
        ref = resolve_ref(spec.strip)
        return ref if ref
        if words.size <= 2 && words.all? { _1 =~ NAME }
          raise Unresolved, "#{words.map(&:capitalize).join(' ')} has no check-ins of this file."
        end
        raise Unresolved, "\"#{spec.strip}\" is not a person, a day or a version."
      end
      list = versions_before(before)
      list = list.select { |v| person_matches?(v, person) } if person
      if person && list.empty?
        name = person == "me" ? "You have" : "#{person.capitalize} has"
        raise Unresolved, "#{name} no check-ins of this file."
      end
      if day
        list = list.select { |v| v.time <= end_of(day) }
        raise Unresolved, "The file did not exist yet on #{day.day} #{MONTHS[day.month - 1].capitalize}." if list.empty?
      end
      list.first
    end

    # The newest version whose text differs from `text` (the to side). This
    # is what "before now" means: the file on disk is a version of its own
    # when it has unsaved-to-git edits, and HEAD when it has none.
    def default_from(text, before: nil)
      versions_before(before).find { |v| @h.text_at(v.sha) != text }
    end

    # The first date in SENT.md beside the file, ISO or "21 October 2026".
    def sent_date
      f = File.join(File.dirname(@h.path), "SENT.md")
      return nil unless File.file?(f)
      s = File.read(f)
      if (m = s.match(/(\d{4})-(\d{2})-(\d{2})/))
        return Date.new(m[1].to_i, m[2].to_i, m[3].to_i)
      end
      if (m = s.match(/(\d{1,2})\s+([[:alpha:]]+)\s+(\d{4})/))
        mi = month_index(m[2])
        return Date.new(m[3].to_i, mi + 1, m[1].to_i) if mi
      end
      nil
    rescue Date::Error
      nil
    end

    def shortcuts
      me = @h.user_name
      others = @h.versions.map(&:author).uniq.reject { _1 == me }
      out = others.map { |n| { "label" => "#{who_of(n)}'s last edit", "spec" => who_of(n).downcase } }
      out << { "label" => "my last edit", "spec" => "me" }
      out << { "label" => "yesterday", "spec" => "yesterday" }
      out << { "label" => "a week ago", "spec" => "a week ago" }
      out << { "label" => "when it was sent", "spec" => "sent" } if sent_date
      out
    end

    def display(v)
      return { "label" => "Now", "who" => "Now" } if v == :now
      { "who" => who_of(v.author, v.email), "name" => v.author, "sha" => v.sha,
        "when" => v.time.strftime("%a %-d %b, %-l:%M %P"),
        "long" => v.time.strftime("%A %-d %B %Y, %-l:%M %P"),
        "iso" => v.time.iso8601, "subject" => v.subject, "body" => v.body }
    end

    private

    def first_name(name) = name.to_s.split(/\s+/).first.to_s

    # The short name a version is shown under. A one-word git handle such
    # as "dannymalonerace" reads as "Danny" when the email's first segment
    # (danny.malone@…) is a prefix of it.
    def who_of(name, email = nil)
      first = first_name(name)
      return first if name.to_s.include?(" ")
      email ||= @h.versions.find { _1.author == name }&.email
      seg = email.to_s.split("@").first.to_s.split(/[._-]/).first.to_s.downcase
      return seg.capitalize if seg.length >= 3 && first.downcase.start_with?(seg) && seg.length < first.length
      first
    end

    def end_of(day) = Time.new(day.year, day.month, day.day, 23, 59, 59, @now.utc_offset)

    def resolve_before(rest, before)
      if rest == "now"
        return default_from(@h.disk_text, before: before) || raise(Unresolved, "There is nothing before now.")
      end
      target = resolve(rest)
      target = @h.versions.first if target == :now
      raise Unresolved, "There is nothing before now." if target.nil?
      # Bounded by a to side, "before X" is the one before X when X is that
      # side itself ("before danny fri" against "danny fri"), otherwise the
      # one before X's last check-in inside the bound.
      bounded = before.is_a?(Version)
      target = resolve(rest, before: before) if bounded && target.sha != before.sha
      list = versions_before(before)
      i = list.index { _1.sha == target.sha }
      j = if i then i + 1
          elsif bounded && target.sha == before.sha then 0
          end
      if j.nil? || j >= list.size
        d = display(target)
        raise Unresolved, "There is nothing before #{d['who']}, #{d['when']}."
      end
      list[j]
    end

    def versions_before(before)
      list = @h.versions
      return list if before.nil? || before == :now
      i = list.index { _1.sha == before.sha }
      i ? list.drop(i + 1) : list
    end

    # "danny" matches "Danny Malone", a one-word handle such as
    # "dannymalonerace", and danny@… in the email.
    def person_matches?(v, person)
      return v.author == @h.user_name if person == "me"
      author = v.author.downcase
      first = author.split(/\s+/).first.to_s
      local = v.email.to_s.downcase.split("@").first.to_s
      author == person || first == person ||
        (person.length >= 3 && (first.start_with?(person) || local.start_with?(person)))
    end

    def known_person?(word)
      @h.versions.any? { |v| person_matches?(v, word) }
    end

    # Leading words that are a name (or "me") against the file's authors.
    # `original` keeps the spec's case for the ref check (HEAD, not head).
    def split_person(words, original)
      return ["me", words.drop(1)] if words.first == "me"
      authors = @h.versions.map { _1.author.downcase }.uniq
      full = words.join(" ")
      authors.each do |a|
        parts = a.split(/\s+/)
        return [parts.first, words.drop(parts.size)] if full == a || full.start_with?("#{a} ")
      end
      return [words.first, words.drop(1)] if known_person?(words.first)
      # An unknown single word that is not a day or a ref is still a person.
      if words.size == 1 && words.first =~ NAME && parse_day(words.first).nil? && !resolvable_ref?(original)
        return [words.first, []]
      end
      [nil, words]
    end

    def resolvable_ref?(s) = !resolve_ref(s).nil?

    def today = Date.new(@now.year, @now.month, @now.day)

    def month_index(mon)
      mon = mon.downcase
      return nil if mon.size < 3
      MONTHS.index { |x| x == mon || x.start_with?(mon) }
    end

    def parse_day(s)
      s = s.strip
      return today if s == "today"
      return today - 1 if s == "yesterday"
      return today - 7 if s == "a week ago" || s == "last week" || s == "1 week ago"
      if (m = s.match(/\A(\d+)\s+(day|week)s?\s+ago\z/))
        return today - m[1].to_i * (m[2] == "week" ? 7 : 1)
      end
      if (m = s.match(/\A(\d{4})-(\d{2})-(\d{2})\z/))
        return Date.new(m[1].to_i, m[2].to_i, m[3].to_i) rescue nil
      end
      if (i = DAYS.index { |d| d == s || d[0, 3] == s })
        back = (today.wday - i) % 7
        back = 7 if back.zero?
        return today - back
      end
      m = s.match(/\A(\d{1,2})\s+([[:alpha:]]+)(?:\s+(\d{4}))?\z/) || s.match(/\A([[:alpha:]]+)\s+(\d{1,2})(?:\s+(\d{4}))?\z/)
      if m
        day, mon = m[1] =~ /\d/ ? [m[1], m[2]] : [m[2], m[1]]
        mi = month_index(mon)
        return nil unless mi
        year = (m[3] || @now.year).to_i
        d = Date.new(year, mi + 1, day.to_i) rescue nil
        d = d.prev_year if d && m[3].nil? && d > today
        return d
      end
      nil
    end

    # Anything git rev-parse accepts; a commit outside the file's history is
    # still shown as its person and time.
    def resolve_ref(ref)
      return nil unless @h.in_repo? && ref =~ /\A[\w.~^@{}\/-]+\z/
      sha = git("rev-parse", "--verify", "-q", "#{ref}^{commit}")
      return nil unless sha
      sha = sha.strip
      @h.versions.find { _1.sha == sha } || begin
        rec = git("show", "-s", "--format=%H\x1f%an\x1f%ae\x1f%aI\x1f%s\x1f%b", sha)
        return nil unless rec
        h, an, ae, date, subject, body = rec.split("\x1f", 6)
        Version.new(h, an, ae, Time.parse(date).localtime, subject, (body || "").strip)
      end
    end

    def git(*args)
      out = IO.popen(["git", *args], chdir: @h.root, err: File::NULL, &:read)
      $?.success? ? out : nil
    rescue Errno::ENOENT
      nil
    end

    def resolve_sent(before)
      d = sent_date or raise Unresolved, "There is no sent date in this directory."
      versions_before(before).find { _1.time <= end_of(d) } or raise Unresolved, "The file did not exist yet when it was sent."
    end
  end
end
