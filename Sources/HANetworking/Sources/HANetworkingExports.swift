// Re-export the model + database layers HANetworking is built on, so a target that links only
// HANetworking (e.g. the watch widget extension, which can't link Shared) can use `WatchComplicationConfig`
// and GRDB without separately linking HAModels/GRDB — which, as static products, would duplicate their
// type-metadata across images and crash. One copy lives inside HANetworking.framework.
@_exported import GRDB
@_exported import HAModels
