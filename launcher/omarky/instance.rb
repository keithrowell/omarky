module Omarky
  # One Quickshell app as a single background process: the first launch
  # starts qs and holds a lock; later launches find the lock held and hand
  # their targets to that process over IPC. Each app names itself and keeps
  # its own lock, state directory and environment prefix:
  #
  #   app = Omarky::Instance.new(name: "omaread", root: ROOT, shell: "ui/shell.qml")
  #   app.open(["/abs/file.md"], foreground: false)
  #
  # The environment the window reads: <PREFIX>_OPEN (one target per line),
  # <PREFIX>_INSTANCE (a private lock name, for checks), <PREFIX>_STATE_DIR
  # (where qs.log goes), <PREFIX>_BIN (the launcher's own path, for a window
  # that needs to run it). The IPC target and the lock directory are the
  # app's name.
  class Instance
    LOG_RULES = "qt.qml.usedbeforedeclared=false;qt.qpa.services.warning=false"

    attr_reader :name, :root, :prefix

    def initialize(name:, root:, shell: "ui/shell.qml", bin: "bin/#{name}", ipc: name, prefix: name.upcase)
      @name = name
      @root = root
      @shell = shell
      @bin = bin
      @ipc = ipc
      @prefix = prefix
      @state = ENV["#{prefix}_STATE_DIR"] || File.join(ENV["XDG_STATE_HOME"] || File.join(Dir.home, ".local/state"), name)
      @runtime = File.join(ENV["XDG_RUNTIME_DIR"] || "/tmp", name)
      @instance = ENV["#{prefix}_INSTANCE"] || name
    end

    def state_dir = @state
    def lock_path = File.join(@runtime, "#{@instance}.lock")

    # Fast path: a running instance holds the lock, so hand it the targets
    # (an empty list opens the app's empty window). Otherwise start one
    # detached qs process, or exec it in the foreground. `env` is merged in
    # before qs starts, after the renderer's own XDG_DATA_DIRS entry.
    def open(targets, foreground: false, env: {})
      ENV["XDG_DATA_DIRS"] = "#{Dir.home}/.local/share/omaread/ksh:#{ENV['XDG_DATA_DIRS'] || '/usr/local/share:/usr/share'}"
      env.each { |k, v| ENV[k] = v }
      if (pid = running_pid)
        ok = (targets.empty? ? [""] : targets).all? do |t|
          system("qs", "ipc", "--pid", pid, "call", @ipc, "open", t, out: File::NULL, err: File::NULL)
        end
        return 0 if ok
      end
      ENV["#{@prefix}_OPEN"] = targets.join("\n")
      # The window runs the launcher for questions it must not answer itself (git).
      ENV["#{@prefix}_BIN"] = File.join(@root, @bin)
      # Log rules: the minified markdown-it trips a declaration-order lint, and
      # Qt logs a portal app-ID clash on every Quickshell app; neither is ours
      # to fix (decision 0008).
      args = ["qs", "--log-rules", LOG_RULES, "-p", File.join(@root, @shell)]
      exec(*args) if foreground
      FileUtils.mkdir_p(@state)
      log = File.open(File.join(@state, "qs.log"), "w")
      pid = fork do
        Process.setsid
        exec(*args, in: File::NULL, out: log, err: log)
      end
      log.close
      Process.detach(pid)
      0
    end

    # The pid in the lock file, when the lock is held and that pid is alive.
    def running_pid
      return nil unless File.file?(lock_path)
      File.open(lock_path) do |f|
        if f.flock(File::LOCK_EX | File::LOCK_NB)
          f.flock(File::LOCK_UN)
          return nil
        end
      end
      pid = File.read(lock_path).strip
      return nil if pid.empty?
      Process.kill(0, pid.to_i)
      pid
    rescue Errno::ESRCH, Errno::EPERM, Errno::ENOENT
      nil
    end

    # The header comment of a launcher script, less the shebang.
    def help(script)
      lines = File.readlines(script).drop(1).take_while { _1.start_with?("#") }
      puts lines.map { _1.sub(/\A# ?/, "") }
      0
    end

    def version(version_file)
      puts "#{@name} #{File.read(version_file).strip}"
      0
    end
  end
end
