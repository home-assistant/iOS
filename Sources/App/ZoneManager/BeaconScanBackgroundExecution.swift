protocol BeaconScanBackgroundExecution: AnyObject {
    func begin(expirationHandler: @escaping () -> Void)
    func end()
}
