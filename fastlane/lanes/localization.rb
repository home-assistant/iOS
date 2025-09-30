# Localization and strings management lanes

desc 'Download latest localization files from Lokalize'
lane :update_strings do
  token = ENV.fetch('LOKALISE_API_TOKEN') do
    prompt(
      text: 'API token',
      secure_text: true
    )
  end

  project_id = ENV.fetch('LOKALISE_PROJECT_ID') do
    prompt(
      text: 'Project ID',
      secure_text: true
    )
  end

  frontend_project_id = ENV.fetch('LOKALISE_PROJECT_ID_FRONTEND') do
    prompt(
      text: 'Frontend Project ID',
      secure_text: true
    )
  end

  core_project_id = ENV.fetch('LOKALISE_PROJECT_ID_CORE') do
    prompt(
      text: 'Core Project ID',
      secure_text: true
    )
  end

  resources_dir_full = File.expand_path('../Sources/App/Resources')

  sh(
    'lokalise2',
    '--token', token,
    '--project-id', project_id,
    'file', 'download',
    '--format', 'ios_sdk',
    '--export-empty-as', 'base',
    '--export-sort', 'a_z',
    '--replace-breaks=false',
    '--include-comments=false',
    '--include-description=false',
    '--unzip-to', resources_dir_full,
    log: false
  )

  lang_frontend_to_ios = {
    'bg' => 'bg',
    'ca' => 'ca-ES',
    'cs' => 'cs',
    'cy' => 'cy-GB',
    'da' => 'da',
    'de' => 'de',
    'el' => 'el',
    'en-GB' => 'en-GB',
    'en' => 'en',
    'es' => 'es-ES',
    'es-419' => 'es',
    # es-MX is missing from the frontend, so we copy es over below
    'et' => 'et',
    'fi' => 'fi',
    'fr' => 'fr',
    'he' => 'he',
    'hu' => 'hu',
    'id' => 'id',
    'it' => 'it',
    'ja' => 'ja',
    'ko' => 'ko-KR',
    'ml' => 'ml',
    'nb' => 'nb',
    'nl' => 'nl',
    'pl' => 'pl-PL',
    'pt-BR' => 'pt-BR',
    'ru' => 'ru',
    'sl' => 'sl',
    'sv' => 'sv',
    'tr' => 'tr',
    'uk' => 'uk',
    'vi' => 'vi',
    'zh-Hans' => 'zh-Hans',
    'zh-Hant' => 'zh-Hant'
  }

  # to => from, since to is unique but from may not be
  manually_copied_languages = {
    'es-MX' => 'es'
  }

  # make sure the previous map has everything. adding a new language should error.
  ios_languages = Set.new(
    Dir.children(resources_dir_full)
    .select { |file| File.extname(file) == '.lproj' }
    .map { |file| File.basename(file, File.extname(file)) }
    .reject { |lang| lang == 'Base' }
  )

  mapped_ios_languages = Set.new(lang_frontend_to_ios.values + manually_copied_languages.keys)

  unless ios_languages == mapped_ios_languages
    missing = ios_languages - mapped_ios_languages
    UI.user_error!("missing language in map. missing: #{missing.to_a.join(', ')}")
  end

  language_mapping = lang_frontend_to_ios
                     .map { |key, value| { 'original_language_iso' => key, custom_language_iso: value } }

  sh(
    'lokalise2',
    '--token', token,
    '--project-id', frontend_project_id,
    'file', 'download',
    '--format', 'strings',
    '--filter-langs', lang_frontend_to_ios.keys.join(','),
    '--language-mapping', language_mapping.to_json.to_s,
    '--original-filenames=false',
    '--bundle-structure', '%LANG_ISO%.lproj/Frontend.%FORMAT%',
    '--export-empty-as', 'base',
    '--export-sort', 'a_z',
    '--replace-breaks=false',
    '--include-comments=false',
    '--include-description=false',
    '--unzip-to', resources_dir_full,
    log: false
  )

  manually_copied_languages.each do |to, from|
    FileUtils.cp(
      "#{resources_dir_full}/#{from}.lproj/Frontend.strings",
      "#{resources_dir_full}/#{to}.lproj/Frontend.strings"
    )
  end

  sh(
    'lokalise2',
    '--token', token,
    '--project-id', core_project_id,
    'file', 'download',
    '--format', 'strings',
    '--filter-langs', lang_frontend_to_ios.keys.join(','),
    '--language-mapping', language_mapping.to_json.to_s,
    '--original-filenames=false',
    '--bundle-structure', '%LANG_ISO%.lproj/Core.%FORMAT%',
    '--export-empty-as', 'base',
    '--export-sort', 'a_z',
    '--replace-breaks=false',
    '--include-comments=false',
    '--include-description=false',
    '--unzip-to', resources_dir_full,
    log: false
  )

  manually_copied_languages.each do |to, from|
    FileUtils.cp(
      "#{resources_dir_full}/#{from}.lproj/Core.strings",
      "#{resources_dir_full}/#{to}.lproj/Core.strings"
    )
  end

  sh('cd ../ && ./Pods/SwiftGen/bin/swiftgen')
end

desc 'Upload localized strings to Lokalise'
lane :push_strings do
  source_directories = [
    '../Sources/App/Resources/en.lproj'
  ]

  token = ENV.fetch('LOKALISE_API_TOKEN') do
    prompt(
      text: 'API token',
      secure_text: true
    )
  end

  project_id = ENV.fetch('LOKALISE_PROJECT_ID') do
    prompt(
      text: 'Project ID',
      secure_text: true
    )
  end

  source_directories.each do |directory|
    puts "Enumerating #{directory}..."
    Dir.each_child(directory) do |file|
      next if ['Frontend.strings', 'Core.strings'].include?(file)

      puts "Uploading file #{file}"
      sh(
        'lokalise2',
        '--token', token,
        '--project-id', project_id,
        'file', 'upload',
        '--file', "#{directory}/#{file}",
        '--lang-iso', 'en',
        log: false
      )
    end
  end
end

desc 'Find unused localized strings'
lane :unused_strings do
  files = [
    '../Sources/App/Resources/en.lproj/Localizable.strings'
  ]
  files.each do |file|
    puts "Looking at #{file}"
    unused_strings = File.read(file)
                         # grab the keys only
                         .scan(/"([^"]+)" = [^;]+;/)
                         # replace _ in the keys with nothing, which is what swiftgen does
                         .map { |s| [s[0], s[0].gsub('_', '')] }
                         # ignore any keys at the root level (aka like ok_label)
                         .select { |full, _key| full.include?('.') }
                         # find any strings that don't have matches in code
                         .select { |_full, key| system("git grep --ignore-case --quiet #{key} -- ../*.swift") == false }
    unused_strings.each_key { |full| puts full }
    puts "- Found #{unused_strings.count} unused strings"
  end
end

desc 'Upload App Store Connect metadata to Lokalise'
lane :update_lokalise_metadata do
  lokalise_metadata(action: 'update_lokalise', override_translation: true)
end

desc 'Download App Store Connect metadata from Lokalise and upload to App Store Connect Connect'
lane :update_asc_metadata do
  lokalise_metadata(action: 'update_itunes')
end
