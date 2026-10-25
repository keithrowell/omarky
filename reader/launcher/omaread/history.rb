module OmaRead
  Version = Struct.new(:sha, :author, :email, :time, :subject, :body)

  # One file's git history, read through the git command.
  class History
    SEP = "\x1f"
    REC = "\x1e"

    attr_reader :path

    def initialize(path)
      @path = File.expand_path(path)
      @root = git_out("rev-parse", "--show-toplevel", dir: File.dirname(@path))&.strip
      @root = nil if @root && @root.empty?
    end

    def in_repo? = !@root.nil?
    def root = @root

    # Path relative to the work tree. Both sides are realpaths because git
    # reports the toplevel with symlinks resolved.
    def rel
      real = File.realpath(@path)
      real.delete_prefix("#{File.realpath(@root)}/")
    end

    def versions
      return [] unless in_repo?
      @versions ||= begin
        fmt = "%H#{SEP}%an#{SEP}%ae#{SEP}%aI#{SEP}%s#{SEP}%b#{REC}"
        out = git_out("log", "--follow", "--format=#{fmt}", "--", rel) || ""
        out.split(REC).map(&:strip).reject(&:empty?).map do |rec|
          sha, an, ae, date, subject, body = rec.split(SEP, 6)
          Version.new(sha, an, ae, Time.parse(date).localtime, subject, (body || "").strip)
        end
      end
    end

    def text_at(sha)
      return nil unless in_repo?
      # --follow may have renamed the file; ask git where it was at that commit.
      out = git_out("show", "#{sha}:#{rel}")
      return out if out
      name = git_out("log", "--follow", "--format=", "--name-only", "-1", sha, "--", rel)
      name = name&.strip
      name && !name.empty? ? git_out("show", "#{sha}:#{name}") : nil
    end

    def disk_text = File.read(@path)

    def user_name = (git_out("config", "user.name") || "").strip

    private

    def git_out(*args, dir: @root || File.dirname(@path))
      out = IO.popen(["git", *args], chdir: dir, err: File::NULL, &:read)
      $?.success? ? out : nil
    rescue Errno::ENOENT
      nil
    end
  end
end
