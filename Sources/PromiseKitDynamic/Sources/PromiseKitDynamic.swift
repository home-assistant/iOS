// Re-export PromiseKit so that `import PromiseKit` continues to work unchanged
// throughout the app while the actual PromiseKit code is compiled into this
// single dynamic framework (see Package.swift for the full rationale).
//
// Consumers keep writing `import PromiseKit`; they just need to *link* this
// dynamic product instead of the static PromiseKit product. The module stays
// visible transitively, and the symbols resolve against this one shared binary.
@_exported import PromiseKit

// Also re-export HAKit's PromiseKit glue so `import HAKit_PromiseKit` keeps working
// everywhere while its (and PromiseKit's) code lives only in this one dynamic framework.
@_exported import HAKit_PromiseKit
