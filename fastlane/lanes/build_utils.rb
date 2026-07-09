# Build and deployment utilities

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

    if output.include?('90382') || output.include?('Upload limit reached')
      report_upload_limit_reached(type: options[:type])
      UI.user_error!('App Store upload limit reached (error 90382). See the job summary for details.')
    end

    attempts += 1
    UI.user_error!("altool upload failed after #{attempts} attempts.") if attempts > 3

    puts 'Failed to upload; retrying upload...'
  end
end

def report_upload_limit_reached(type:)
  store = type == 'osx' ? 'Mac App Store' : 'App Store'
  message = "#{store} upload failed: Apple daily upload limit reached (error 90382). " \
            'The app built, notarized and stapled fine; this is an App Store Connect ' \
            'per-app daily quota, not a build failure. Wait ~24h for the reset, then re-run.'

  UI.error(message)
  puts "::error title=#{store} upload limit reached (90382)::#{message}"
  append_job_summary(upload_limit_summary(store, type))
end

def upload_limit_summary(store, type)
  [
    "## :x: #{store} upload failed: daily upload limit reached (90382)",
    '',
    "Apple returned **error 90382 (\"Upload limit reached\")** for the `#{type}` package.",
    '',
    '- The app **built, notarized and stapled successfully**, so this is not a build or code failure.',
    '- App Store Connect enforces a **per-app daily upload quota**, which has now been exhausted.',
    "- **Action:** wait ~24h for Apple's window to reset, then re-run. Re-running sooner hits the same limit."
  ].join("\n")
end

def append_job_summary(text)
  summary_path = ENV.fetch('GITHUB_STEP_SUMMARY', nil)
  return if summary_path.nil? || summary_path.empty?

  File.write(summary_path, "#{text}\n", mode: 'a')
end
