# Code quality and linting lanes

lane :lint do
  sh('cd .. ; Pods/SwiftFormat/CommandLineTool/swiftformat --config .swiftformat --lint --quiet .')
  sh('cd .. ; Pods/SwiftLint/swiftlint lint --config .swiftlint.yml --quiet .')
  sh('cd .. ; bundle exec rubocop --config .rubocop.yml')
end

lane :autocorrect do
  sh('../Pods/SwiftFormat/CommandLineTool/swiftformat ..')
  sh('bundle exec rubocop -a ..')
end