# Build and deployment utilities

private_lane :upload_binary_to_apple do |options|
  attempts = 0

  begin
    sh(
      'xcrun', 'altool', '--upload-app', '--type', options[:type],
      '--file', options[:path],
      '--username', ENV.fetch('DELIVER_USERNAME', nil),
      '--password', '@env:FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD'
    )
  rescue StandardError => e
    puts "Failed with #{e}; retrying upload..."

    # retry a few times, then give up
    attempts += 1

    retry if attempts <= 3
    raise e
  end
end