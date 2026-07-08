#!/usr/bin/env ruby

require 'json'

workspace_path = ENV['WORKSPACE_PATH']
workspace_path ||= Dir[File.join(ENV.fetch('WORKSPACE_DIR'), '*.xcworkspace')].first
abort('Unable to locate workspace path') unless workspace_path

project_dir = ENV.fetch('PROJECT_DIR')

input_path = File.join(workspace_path, 'xcshareddata', 'swiftpm', 'Package.resolved')
output_path = File.join(project_dir, 'Package.resolved')

resolved = JSON.parse(File.read(input_path))
pins = resolved.fetch('pins').map do |pin|
  location = pin['location']
  next unless location

  {
    'package' => pin['identity'],
    'repositoryURL' => location,
    'state' => pin['state'],
  }
end.compact

File.write(
  output_path,
  JSON.pretty_generate(
    {
      'object' => {
        'pins' => pins,
      },
      'version' => 1,
    }
  )
)
