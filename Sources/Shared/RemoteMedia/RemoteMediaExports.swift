// Re-exported so files that `import Shared` (and the tests) resolve the package's types without linking
// it a second time. This folder belongs to `Shared-iOS` only, which is the only target that links it.
@_exported import HARemoteMedia
