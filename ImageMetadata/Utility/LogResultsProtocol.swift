//

public protocol LogResults {
    func log(_ message: String)
    var isCanceled: Bool { get }
}
