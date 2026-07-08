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
