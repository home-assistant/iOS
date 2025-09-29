# Version management lanes

private_lane :set_version_info do |options|
  File.write(
    '../Configuration/Version.xcconfig',
    "MARKETING_VERSION=#{options[:version]}\nCURRENT_PROJECT_VERSION=#{options[:build]}\n"
  )
end

private_lane :get_xcconfig_marketing_version do
  sh('cd .. ; . Configuration/Version.xcconfig ; echo $MARKETING_VERSION').strip!
end

private_lane :get_xcconfig_build_number do
  sh('cd .. ; . Configuration/Version.xcconfig; echo $CURRENT_PROJECT_VERSION').strip!
end

desc 'Set version number'
lane :set_version do |options|
  version = options[:version]

  unless version
    if is_ci
      UI.error 'no version provided'
    else
      version = prompt(text: 'Version number: ')
    end
  end

  set_version_info(
    version: version,
    build: get_xcconfig_build_number
  )
end