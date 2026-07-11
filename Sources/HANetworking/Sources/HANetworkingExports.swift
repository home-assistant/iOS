// Re-export the model/database/networking dependency modules that HANetworking statically absorbs, so
// consumers link them from the ONE copy inside HANetworking.framework instead of linking their own
// static copy. This is what lets `Shared` (and the watch widget) drop their direct dependencies on
// these packages: a second static copy in another image duplicates type-metadata / protocol
// conformances and causes "spurious casting failures and mysterious crashes" (see
// [[spm-static-products-only-in-shared]]). Consumers keep writing `import GRDB` / `import Alamofire`
// etc.; the module stays visible transitively and the symbols resolve against this one framework.
@_exported import Alamofire
@_exported import GRDB
@_exported import HAModels
@_exported import KeychainAccess
@_exported import ObjectMapper
