module FixtureRepo
  COMMITS = [
    ["Keith Rowell", "keith@example.com", "2026-10-07T18:20:00+10:00", "Start the proposal", "v1 start\n\nSituation one.\n"],
    ["Keith Rowell", "keith@example.com", "2026-10-08T08:31:00+10:00", "Situation from the call notes", "v2\n\nSituation two.\n"],
    ["Danny Malone", "danny@example.com", "2026-10-17T14:50:00+10:00", "First pass at the approach", "v3\n\nApproach one.\n"],
    ["Keith Rowell", "keith@example.com", "2026-10-20T11:08:00+10:00", "Team section", "v4\n\nTeam.\n"],
    ["Danny Malone", "danny@example.com", "2026-10-23T16:12:00+10:00", "Tighten the approach section\n\nTwelve weeks reads as long.", "v5\n\nApproach two.\n"],
    ["Keith Rowell", "keith@example.com", "2026-10-24T17:02:00+10:00", "Use the client's name", "v6\n\nApproach three.\n"],
  ]

  # Builds the repo in dir; returns the document path. Commit times are the
  # author dates above, so date specs resolve to known commits.
  def self.build(dir, file: "proposal.md")
    path = File.join(dir, file)
    run(dir, "git", "init", "-q", "-b", "main")
    run(dir, "git", "config", "user.name", "Keith Rowell")
    run(dir, "git", "config", "user.email", "keith@example.com")
    File.write(File.join(dir, "SENT.md"), "Sent to the client on 21 October 2026.\n")
    COMMITS.each do |name, email, date, msg, text|
      File.write(path, text)
      run(dir, "git", "add", ".")
      env = { "GIT_AUTHOR_NAME" => name, "GIT_AUTHOR_EMAIL" => email, "GIT_AUTHOR_DATE" => date,
              "GIT_COMMITTER_NAME" => name, "GIT_COMMITTER_EMAIL" => email, "GIT_COMMITTER_DATE" => date }
      run(dir, env, "git", "commit", "-q", "-m", msg)
    end
    path
  end

  def self.run(dir, *cmd)
    env = cmd.first.is_a?(Hash) ? cmd.shift : {}
    system(env, *cmd, chdir: dir, out: File::NULL, err: File::NULL) or raise "failed: #{cmd.join(' ')}"
  end
end
