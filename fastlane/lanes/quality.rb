# Code quality and linting lanes

lane :lint do
  sh('cd .. ; Tools/build_tool swiftformat --config .swiftformat --lint --quiet .')
  sh('cd .. ; Tools/build_tool swiftlint lint --config .swiftlint.yml --quiet .')
  sh('cd .. ; bundle exec rubocop --config .rubocop.yml')
end

lane :autocorrect do
  sh('../Tools/build_tool swiftformat ..')
  sh('bundle exec rubocop -a ..')
end

desc 'Install the git pre-commit hook that runs autocorrect before each commit'
lane :install_git_hooks do |options|
  current = sh('cd .. ; git config --default "" core.hooksPath', log: false).strip

  if current == '.githooks'
    UI.success('Git hooks already installed (core.hooksPath is .githooks).')
    next
  end

  unless current.empty? || options[:force]
    message = "core.hooksPath is already set to '#{current}'. " \
              'Re-run with `install_git_hooks force:true` to override it.'
    UI.user_error!(message)
  end

  sh('cd .. ; git config core.hooksPath .githooks')
  UI.success('Installed git hooks. `bundle exec fastlane autocorrect` will run before each commit.')
end
