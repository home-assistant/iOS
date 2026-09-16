# Build and deployment utilities

# Apple can answer one upload with several errors at once, and the first one listed is not always
# the one that matters: a rejected toolchain arrives alongside the daily quota error, and only the
# toolchain is actionable. These are ordered most- to least-actionable and the first match wins, so
# "wait a day and re-run" is never the advice when re-running cannot work.
#
# None of them are worth retrying — altool gets the same answer every time — so a match fails the
# lane immediately instead of spending the retry budget re-uploading a binary Apple already refused.
ALTOOL_FATAL_FAILURES = [
  {
    codes: %w[90301 90534],
    title: 'Xcode version no longer accepted',
    reason: 'App Store Connect only accepts builds from the current Xcode release or release ' \
            'candidate, and this one was built with an Xcode that is now older than that.',
    action: 'Re-running will not help. The runner needs a newer Xcode before the app can be uploaded.'
  },
  {
    codes: %w[90382],
    title: 'daily upload limit reached',
    reason: 'App Store Connect enforces a per-app daily upload quota, which has now been exhausted.',
    action: "Wait ~24h for Apple's window to reset, then re-run. Re-running sooner hits the same limit."
  }
].freeze

private_lane :upload_binary_to_apple do |options|
  command = [
    'xcrun', 'altool', '--upload-app', '--type', options[:type],
    '--file', options[:path],
    '--username', ENV.fetch('DELIVER_USERNAME', nil),
    '--password', '@env:FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD'
  ]

  attempts = 0

  loop do
    succeeded = false
    output = +''

    sh(*command) do |status, result, _command|
      succeeded = status.success?
      output = result.to_s
    end

    break if succeeded

    failure = fatal_altool_failure(output)
    if failure
      report_altool_failure(failure, type: options[:type], output: output)
      UI.user_error!("#{altool_store(options[:type])} upload failed: #{failure[:title]} " \
                     "(#{failure[:codes].join('/')}). See the job summary for details.")
    end

    attempts += 1
    UI.user_error!("altool upload failed after #{attempts} attempts.") if attempts > 3

    puts 'Failed to upload; retrying upload...'
  end
end

# altool prints each error code parenthesised after its description, which is a tighter match than
# the bare number: an upload UUID or a file path can carry the same digits. The match narrows the
# entry to the codes Apple actually returned, so the report never quotes one it did not send.
def fatal_altool_failure(output)
  ALTOOL_FATAL_FAILURES.each do |failure|
    matched = failure[:codes].select { |code| output.match?(/\(#{code}\)/) }
    return failure.merge(codes: matched) unless matched.empty?
  end

  nil
end

def altool_store(type)
  type == 'osx' ? 'Mac App Store' : 'App Store'
end

# altool runs out of the Xcode that built the archive and prints where it was loaded from. That
# resolved path is what a rejected toolchain has to be read against: DEVELOPER_DIR can name a
# release that is really a beta underneath, so the configured path alone does not say which Xcode
# Apple actually saw.
def altool_xcode(output)
  path = output[/Running altool at path '([^']+)'/, 1]
  return ENV.fetch('DEVELOPER_DIR', 'unknown') if path.nil?

  path[/\A.*?\.app/] || path
end

def report_altool_failure(failure, type:, output:)
  store = altool_store(type)
  # Not "notarized": the iOS lane never notarizes, and the mac lane notarizes the Developer ID app
  # rather than the App Store package this uploads, so neither says anything about what Apple just
  # refused.
  message = "#{store} upload failed: #{failure[:title]} (#{failure[:codes].join('/')}). " \
            "The app built and signed fine. #{failure[:reason]} #{failure[:action]}"

  UI.error(message)
  puts "::error title=#{store} upload failed: #{failure[:title]}::#{message}"
  append_job_summary(altool_failure_summary(failure, type, output))
end

def altool_failure_summary(failure, type, output)
  [
    "## :x: #{altool_store(type)} upload failed: #{failure[:title]}",
    '',
    "Apple returned **#{failure[:codes].join(' / ')}** for the `#{type}` package.",
    '',
    *altool_failure_summary_bullets(failure, output)
  ].join("\n")
end

def altool_failure_summary_bullets(failure, output)
  [
    '- The package **built and signed successfully**, so this is not a build or code failure.',
    "- #{failure[:reason]}",
    "- Uploaded from **#{altool_xcode(output)}** (`DEVELOPER_DIR` is " \
    "`#{ENV.fetch('DEVELOPER_DIR', 'unset')}`).",
    "- **Action:** #{failure[:action]}"
  ]
end

def append_job_summary(text)
  summary_path = ENV.fetch('GITHUB_STEP_SUMMARY', nil)
  return if summary_path.nil? || summary_path.empty?

  File.write(summary_path, "#{text}\n", mode: 'a')
end
