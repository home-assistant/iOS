# Resolves the Apple account ("flavor") the checkout builds for from the xcconfig files, so the
# lanes never hard-code a bundle identifier or a provisioning profile folder.

def account_xcconfig_path
  selectors = ['../Configuration/Account.local.xcconfig', '../Configuration/Account.xcconfig']
  selector = selectors.find { |path| File.exist?(path) }
  included = File.read(selector)[/^#include\s+"([^"]+)"/, 1]
  UI.user_error!("#{selector} does not include an account xcconfig") unless included
  File.expand_path(included, File.dirname(selector))
end

def account_settings
  @account_settings ||= File.foreach(account_xcconfig_path).each_with_object({}) do |line, settings|
    match = line.match(%r{^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*(//.*)?$})
    settings[match[1]] = match[2] if match
  end
end

def account_setting(name)
  value = account_settings.fetch(name) { UI.user_error!("#{name} is not set in #{account_xcconfig_path}") }
  value.gsub(/\$[({]([A-Z0-9_]+)[)}]/) { account_settings.fetch(Regexp.last_match(1), '') }
end

def account_app_identifier
  account_setting('APP_BUNDLE_ID_BASE')
end

def account_provisioning_directory
  "../#{account_setting('PROVISIONING_PROFILES_DIR')}"
end
