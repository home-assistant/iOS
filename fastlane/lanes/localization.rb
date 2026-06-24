# Localization and strings management lanes

require 'base64'
require 'json'
require 'net/http'
require 'set'
require 'tmpdir'
require 'uri'

def lokalise_request!(request_options)
  response, parsed_body, path = lokalise_perform_request(request_options)
  lokalise_raise_for_error!(
    response: response,
    parsed_body: parsed_body,
    path: path,
    accepted_response_classes: request_options.fetch(:accepted_response_classes, [Net::HTTPSuccess])
  )
  parsed_body
end

def lokalise_perform_request(request_options)
  path = request_options.fetch(:path)
  uri = URI("https://api.lokalise.com/api2/projects/#{request_options.fetch(:project_id)}#{path}")
  request = lokalise_request_class(request_options.fetch(:http_method)).new(uri)
  lokalise_configure_request!(request: request, token: request_options.fetch(:token), body: request_options[:body])
  response = lokalise_http_response(uri: uri, request: request)
  [response, lokalise_response_body(response), path]
end

def lokalise_request_class(http_method)
  case http_method
  when :get
    Net::HTTP::Get
  when :post
    Net::HTTP::Post
  when :delete
    Net::HTTP::Delete
  else
    raise ArgumentError, "Unsupported Lokalise HTTP method: #{http_method}"
  end
end

def lokalise_configure_request!(request:, token:, body:)
  request['Accept'] = 'application/json'
  request['Content-Type'] = 'application/json' if body
  request['X-Api-Token'] = token
  request.body = JSON.generate(body) if body
end

def lokalise_http_response(uri:, request:)
  Net::HTTP.start(
    uri.host,
    uri.port,
    use_ssl: true,
    open_timeout: 30,
    read_timeout: 30
  ) do |http|
    http.request(request)
  end
end

def lokalise_response_body(response)
  return {} if response.body.to_s.empty?

  JSON.parse(response.body)
rescue JSON::ParserError
  {}
end

def lokalise_raise_for_error!(response:, parsed_body:, path:, accepted_response_classes:)
  return if accepted_response_classes.any? { |klass| response.is_a?(klass) }

  error_details = parsed_body['error'] || parsed_body['message'] || response.body
  UI.user_error!("Lokalise API request failed for #{path} (HTTP #{response.code}): #{error_details}")
end

def lokalise_process_id(payload)
  payload['process_id'] || payload.dig('process', 'process_id') || payload['id'] || payload.dig('process', 'id')
end

def lokalise_process_status(payload)
  payload['status'] || payload.dig('process', 'status')
end

def lokalise_process_message(payload)
  payload['message'] || payload.dig('process', 'message') || payload.dig('details', 'message')
end

def lokalise_bundle_url(payload)
  payload['bundle_url'] ||
    payload.dig('details', 'bundle_url') ||
    payload.dig('details', 'download_url') ||
    payload.dig('process', 'details', 'bundle_url') ||
    payload.dig('process', 'details', 'download_url')
end

def lokalise_download_files_async!(token:, project_id:, export_params:, unzip_to:, export_name:)
  UI.message("Requesting Lokalise export for #{export_name}...")
  bundle_url = lokalise_finished_bundle_url!(
    project_id: project_id,
    token: token,
    export_params: export_params,
    export_name: export_name
  )
  lokalise_unpack_bundle!(bundle_url: bundle_url, unzip_to: unzip_to, export_name: export_name)
end

def lokalise_finished_bundle_url!(project_id:, token:, export_params:, export_name:)
  process_response = lokalise_process_response_for_export!(
    project_id: project_id,
    token: token,
    export_params: export_params,
    export_name: export_name
  )
  bundle_url = lokalise_bundle_url(process_response)
  UI.user_error!("Lokalise export for #{export_name} finished without a bundle URL.") unless bundle_url
  bundle_url
end

def lokalise_process_response_for_export!(project_id:, token:, export_params:, export_name:)
  export_context = { project_id: project_id, token: token, export_name: export_name }
  process_id = lokalise_queue_export!(**export_context, export_params: export_params)
  lokalise_wait_for_finished_export!(**export_context, process_id: process_id)
end

def lokalise_queue_export!(project_id:, token:, export_params:, export_name:)
  queue_response = lokalise_request!(
    project_id: project_id,
    token: token,
    http_method: :post,
    path: '/files/async-download',
    body: export_params
  )
  lokalise_process_id!(queue_response, "Lokalise did not return a process id for #{export_name}.")
end

def lokalise_upload_file!(token:, project_id:, file_path:, lang_iso:)
  file_name = File.basename(file_path)
  UI.message("Uploading #{file_name} to Lokalise...")
  upload_context = lokalise_upload_context(
    token: token, project_id: project_id, file_path: file_path, file_name: file_name, lang_iso: lang_iso
  )
  process_id = lokalise_queue_upload!(**upload_context)
  lokalise_finish_upload!(token: token, project_id: project_id, process_id: process_id, file_name: file_name)
end

def lokalise_queue_upload!(token:, project_id:, file_path:, file_name:, lang_iso:)
  upload_response = lokalise_request!(
    lokalise_upload_request_options(
      token: token,
      project_id: project_id,
      file_path: file_path,
      file_name: file_name,
      lang_iso: lang_iso
    )
  )
  lokalise_process_id!(upload_response, "Lokalise did not return a process id for upload #{file_name}.")
end

def lokalise_upload_context(token:, project_id:, file_path:, file_name:, lang_iso:)
  {
    token: token,
    project_id: project_id,
    file_path: file_path,
    file_name: file_name,
    lang_iso: lang_iso
  }
end

def lokalise_finish_upload!(token:, project_id:, process_id:, file_name:)
  lokalise_wait_for_finished_export!(
    project_id: project_id,
    token: token,
    process_id: process_id,
    export_name: "upload #{file_name}"
  )
end

def lokalise_upload_body(file_path:, file_name:, lang_iso:)
  {
    data: Base64.strict_encode64(File.binread(file_path)),
    filename: file_name,
    lang_iso: lang_iso
  }
end

def lokalise_upload_request_options(token:, project_id:, file_path:, file_name:, lang_iso:)
  {
    project_id: project_id,
    token: token,
    http_method: :post,
    path: '/files/upload',
    body: lokalise_upload_body(file_path: file_path, file_name: file_name, lang_iso: lang_iso),
    accepted_response_classes: [Net::HTTPSuccess, Net::HTTPRedirection]
  }
end

def lokalise_process_id!(payload, error_message)
  process_id = lokalise_process_id(payload)
  UI.user_error!(error_message) unless process_id
  process_id
end

def lokalise_wait_for_finished_export!(project_id:, token:, process_id:, export_name:)
  process_response = lokalise_poll_process!(
    project_id: project_id,
    token: token,
    process_id: process_id,
    export_name: export_name
  )
  UI.user_error!("Timed out waiting for Lokalise export for #{export_name}.") unless process_response
  process_response
end

def lokalise_poll_process!(project_id:, token:, process_id:, export_name:)
  60.times do
    sleep 5
    process_response = lokalise_process_response!(project_id: project_id, token: token, process_id: process_id)
    return process_response if lokalise_process_status(process_response) == 'finished'

    lokalise_raise_for_failed_process!(process_response: process_response, export_name: export_name)
  end
  nil
end

def lokalise_process_response!(project_id:, token:, process_id:)
  lokalise_request!(
    project_id: project_id,
    token: token,
    http_method: :get,
    path: "/processes/#{process_id}"
  )
end

def lokalise_raise_for_failed_process!(process_response:, export_name:)
  status = lokalise_process_status(process_response)
  return unless %w[failed cancelled canceled].include?(status)

  UI.user_error!(
    "Lokalise export failed for #{export_name}: #{lokalise_process_message(process_response) || status}"
  )
end

def lokalise_unpack_bundle!(bundle_url:, unzip_to:, export_name:)
  Dir.mktmpdir("lokalise-#{export_name.downcase.tr(' ', '-')}") do |directory|
    archive_path = File.join(directory, "#{export_name.downcase.tr(' ', '_')}.zip")
    File.binwrite(archive_path, lokalise_download_bundle_body!(bundle_url))
    sh('ditto', '-x', '-k', archive_path, unzip_to, log: false)
  end
end

def lokalise_download_bundle_body!(url, redirects_remaining = 5)
  UI.user_error!('Too many redirects while downloading Lokalise bundle.') if redirects_remaining <= 0

  response = lokalise_bundle_response(url)
  return response.body if response.is_a?(Net::HTTPSuccess)
  return lokalise_follow_bundle_redirect!(response, redirects_remaining) if response.is_a?(Net::HTTPRedirection)

  UI.user_error!("Unable to download Lokalise bundle (HTTP #{response.code}): #{response.body}")
end

def lokalise_bundle_response(url, open_timeout: 10, read_timeout: 30, retries_remaining: 1)
  uri = URI(url)
  lokalise_bundle_http_response(uri: uri, open_timeout: open_timeout, read_timeout: read_timeout)
rescue Net::OpenTimeout, Net::ReadTimeout => e
  retry if (retries_remaining -= 1) >= 0

  UI.user_error!("Timed out while downloading Lokalise bundle from #{url}: #{e.class}")
end

def lokalise_bundle_http_response(uri:, open_timeout:, read_timeout:)
  Net::HTTP.start(
    uri.host,
    uri.port,
    use_ssl: uri.scheme == 'https',
    open_timeout: open_timeout,
    read_timeout: read_timeout
  ) do |http|
    http.get(uri.request_uri)
  end
end

def lokalise_follow_bundle_redirect!(response, redirects_remaining)
  lokalise_download_bundle_body!(response['location'], redirects_remaining - 1)
end

# All names a key answers to. key_name is a plain string, or a per-platform
# object ({ ios:, android:, web:, other: }) when per-platform names are enabled.
def lokalise_key_names(key)
  name = key['key_name']
  case name
  when String then [name]
  when Hash then name.values.compact
  else []
  end
end

LOKALISE_KEYS_PAGE_LIMIT = 500

# Resolve requested key names to { name => key_id }, exact match only.
# We page through every key and match names locally rather than relying on the
# Lokalise `filter_keys` query param: its matching semantics are loosely defined
# (and a comma-joined value is unreliable), which is too risky for a destructive op.
def lokalise_find_key_ids!(token:, project_id:, key_names:)
  found = {}
  page = 1
  loop do
    keys = lokalise_keys_page!(token: token, project_id: project_id, page: page)
    lokalise_collect_key_ids!(keys: keys, key_names: key_names, found: found)
    break if keys.length < LOKALISE_KEYS_PAGE_LIMIT

    page += 1
  end
  found
end

def lokalise_keys_page!(token:, project_id:, page:)
  response = lokalise_request!(
    project_id: project_id,
    token: token,
    http_method: :get,
    path: "/keys?limit=#{LOKALISE_KEYS_PAGE_LIMIT}&page=#{page}"
  )
  response['keys'] || []
end

def lokalise_collect_key_ids!(keys:, key_names:, found:)
  keys.each do |key|
    match = key_names.find { |name| lokalise_key_names(key).include?(name) }
    found[match] = key['key_id'] if match
  end
end

def lokalise_delete_keys!(token:, project_id:, key_ids:)
  lokalise_request!(
    project_id: project_id,
    token: token,
    http_method: :delete,
    path: '/keys',
    body: { keys: key_ids }
  )
end

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

  # Intents.strings holds the deprecated SiriKit intent definitions that were
  # migrated to App Intents and removed from the Lokalise upload (see push_strings).
  # The keys still live on Lokalise, so snapshot the existing files and restore them
  # after the download to keep the deprecated strings frozen exactly as committed.
  deprecated_intents_files = Dir.glob("#{resources_dir_full}/*.lproj/Intents.strings").to_h do |path|
    [path, File.binread(path)]
  end

  # The iOS app export is the only download that can regenerate Intents.strings, so
  # wrap it in begin/ensure and restore the snapshot even if the export fails midway.
  begin
    lokalise_download_files_async!(
      token: token,
      project_id: project_id,
      unzip_to: resources_dir_full,
      export_name: 'iOS app strings',
      export_params: {
        format: 'ios_sdk',
        export_empty_as: 'base',
        export_sort: 'a_z',
        replace_breaks: false,
        include_comments: false,
        include_description: false
      }
    )
  ensure
    deprecated_intents_files.each do |path, contents|
      File.binwrite(path, contents)
    end
  end

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

  lokalise_download_files_async!(
    token: token,
    project_id: frontend_project_id,
    unzip_to: resources_dir_full,
    export_name: 'frontend strings',
    export_params: {
      format: 'strings',
      filter_langs: lang_frontend_to_ios.keys,
      language_mapping: language_mapping,
      original_filenames: false,
      bundle_structure: '%LANG_ISO%.lproj/Frontend.%FORMAT%',
      export_empty_as: 'base',
      export_sort: 'a_z',
      replace_breaks: false,
      include_comments: false,
      include_description: false
    }
  )

  manually_copied_languages.each do |to, from|
    FileUtils.cp(
      "#{resources_dir_full}/#{from}.lproj/Frontend.strings",
      "#{resources_dir_full}/#{to}.lproj/Frontend.strings"
    )
  end

  lokalise_download_files_async!(
    token: token,
    project_id: core_project_id,
    unzip_to: resources_dir_full,
    export_name: 'core strings',
    export_params: {
      format: 'strings',
      filter_langs: lang_frontend_to_ios.keys,
      language_mapping: language_mapping,
      original_filenames: false,
      bundle_structure: '%LANG_ISO%.lproj/Core.%FORMAT%',
      export_empty_as: 'base',
      export_sort: 'a_z',
      replace_breaks: false,
      include_comments: false,
      include_description: false
    }
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
      next if ['Frontend.strings', 'Core.strings', 'Intents.strings'].include?(file)

      lokalise_upload_file!(
        token: token,
        project_id: project_id,
        file_path: "#{directory}/#{file}",
        lang_iso: 'en'
      )
    end
  end
end

desc 'Delete keys completely from the iOS app Lokalise project'
lane :delete_lokalise_keys do
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

  raw_keys = ENV.fetch('LOKALISE_DELETE_KEYS') do
    prompt(text: 'Keys to delete (comma or newline separated)')
  end
  key_names = raw_keys.split(/[,\n]/).map(&:strip).reject(&:empty?).uniq
  UI.user_error!('No keys provided to delete.') if key_names.empty?

  dry_run = ENV.fetch('LOKALISE_DELETE_DRY_RUN', 'true').to_s.strip.downcase != 'false'
  confirmation = ENV.fetch('LOKALISE_DELETE_CONFIRMATION', '').to_s.strip

  UI.message("Resolving #{key_names.count} key(s) in Lokalise project #{project_id}...")
  found = lokalise_find_key_ids!(token: token, project_id: project_id, key_names: key_names)

  missing = key_names - found.keys
  UI.important("Not found (skipped): #{missing.join(', ')}") unless missing.empty?

  if found.empty?
    UI.message('No matching keys found. Nothing to delete.')
    next
  end

  found.each { |name, id| UI.message("  #{name} -> #{id}") }

  if dry_run
    UI.important(
      "DRY RUN: would delete #{found.count} key(s). Re-run with " \
      'LOKALISE_DELETE_DRY_RUN=false and LOKALISE_DELETE_CONFIRMATION=DELETE to proceed ' \
      '(via the workflow, set the dry_run and confirmation inputs).'
    )
    next
  end

  unless confirmation == 'DELETE'
    UI.user_error!("Confirmation required: set LOKALISE_DELETE_CONFIRMATION to 'DELETE' to proceed.")
  end

  lokalise_delete_keys!(token: token, project_id: project_id, key_ids: found.values)
  UI.success("Deleted #{found.count} key(s) from Lokalise project #{project_id}.")
end

LOCALIZABLE_STRINGS_GLOB = 'Sources/App/Resources/*.lproj/Localizable.strings'.freeze

# Index of the last physical line of the .strings entry starting at `start`.
# Entries may span lines via trailing-backslash continuation; the last line ends with ';'.
def strings_entry_end(lines, start)
  i = start
  i += 1 while i < lines.length - 1 && !lines[i].rstrip.end_with?(';')
  i
end

# Key names defined in the file (one capture per entry-start line).
def strings_keys(lines)
  lines.filter_map do |line|
    match = line.match(/\A"((?:[^"\\]|\\.)*)" = /)
    match && match[1]
  end
end

# Lines with every entry whose key is in key_set removed (the whole multi-line entry).
def reject_strings_keys(lines, key_set)
  kept = []
  i = 0
  while i < lines.length
    match = lines[i].match(/\A"((?:[^"\\]|\\.)*)" = /)
    drop = !match.nil? && key_set.include?(match[1])
    last = drop ? strings_entry_end(lines, i) : i
    kept.concat(lines[i..last]) unless drop
    i = last + 1
  end
  kept
end

# Removes the requested keys from a single Localizable.strings file.
# Returns the requested keys that were present (and removed) in this file.
def remove_strings_keys!(path:, key_set:)
  lines = File.readlines(path, encoding: 'UTF-8')
  present = strings_keys(lines).select { |key| key_set.include?(key) }.uniq
  return [] if present.empty?

  File.write(path, reject_strings_keys(lines, key_set).join, encoding: 'UTF-8')
  UI.message("#{File.basename(File.dirname(path))}: removed #{present.length} key(s)")
  present
end

desc 'Remove keys from all Localizable.strings files and regenerate SwiftGen output'
lane :delete_local_strings do
  raw_keys = ENV.fetch('LOKALISE_DELETE_KEYS') do
    prompt(text: 'Keys to delete (comma or newline separated)')
  end
  key_names = raw_keys.split(/[,\n]/).map(&:strip).reject(&:empty?).uniq
  UI.user_error!('No keys provided to delete.') if key_names.empty?

  key_set = key_names.to_set
  files = Dir.glob(File.expand_path("../#{LOCALIZABLE_STRINGS_GLOB}"))
  UI.user_error!('No Localizable.strings files found.') if files.empty?

  removed = files.flat_map { |path| remove_strings_keys!(path: path, key_set: key_set) }.uniq
  missing = key_names - removed
  UI.important("Not found in any Localizable.strings: #{missing.join(', ')}") unless missing.empty?

  sh('cd ../ && ./Pods/SwiftGen/bin/swiftgen')
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
