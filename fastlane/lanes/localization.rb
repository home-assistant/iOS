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
      next if ['Frontend.strings', 'Core.strings'].include?(file)

      lokalise_upload_file!(
        token: token,
        project_id: project_id,
        file_path: "#{directory}/#{file}",
        lang_iso: 'en'
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
