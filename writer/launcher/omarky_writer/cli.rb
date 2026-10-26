module OmarkyWriter
  # `omarky write [FILE …] [--end] [--foreground]`: files into targets for the
  # window ("path" or "path<TAB>end"), the native highlighter built when it
  # is stale, then the targets handed to the running instance or a new one.
  class CLI
    def initialize(argv, root:)
      @argv = argv.dup
      @root = root
      @app = Omarky::Instance.new(name: "omarky-writer", root: root, shell: "writer/ui/shell.qml", bin: "bin/omarky", prefix: "OMARKY_WRITER")
      @native = Omarky::Native.new(root: root, source: File.join(root, "native"), state_dir: @app.state_dir)
    end

    def run
      return @app.help(File.join(@root, "bin/omarky")) if @argv.include?("-h") || @argv.include?("--help")
      argv = @argv.dup
      foreground = !argv.delete("--foreground").nil?
      at_end = !argv.delete("--end").nil?
      targets = argv.map do |a|
        path = File.expand_path(a.sub(%r{\Afile://}, ""))
        path = File.realpath(path) if File.exist?(path)
        at_end ? "#{path}\tend" : path
      end
      env = {}
      unless @app.running_pid
        begin
          path = @native.ensure(required: true)
          env["QML_IMPORT_PATH"] = [path, ENV["QML_IMPORT_PATH"]].compact.reject(&:empty?).join(":")
        rescue Omarky::Native::BuildFailed => e
          warn "omarky: #{e.message}"
          system("notify-send", "OmarkyWriter", e.message.sub(/\A./, &:upcase), out: File::NULL, err: File::NULL)
          return 1
        end
      end
      @app.open(targets, foreground: foreground, env: env)
    end
  end
end
