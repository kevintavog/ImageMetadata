//

import Cocoa
import RangicCore
import Async

class LogResultsController : NSWindowController, LogResults {
    @IBOutlet weak var headerText: NSTextField!
    @IBOutlet weak var cancelCloseButton: NSButton!
    @IBOutlet var logText: NSTextView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    var attributes: [NSAttributedString.Key : Any] = [:]


    static func create(header: String) -> LogResultsController {
        let controller = LogResultsController(windowNibName: NSNib.Name(stringLiteral: "LogResultsWindow"))
        controller.setHeader(header: header)
        return controller
    }
    
    override func awakeFromNib() {
        attributes = logText.attributedString().attributes(at: 0, effectiveRange: nil)
        logText.string = ""
        progressIndicator.startAnimation(nil)
    }

    func setHeader(header: String) {
        window?.title = header
        headerText.stringValue = header
    }

    func operationCompleted() {
        progressIndicator.stopAnimation(nil)
        cancelCloseButton.title = "Close"
        headerText.stringValue = "\(headerText.stringValue) - COMPLETED"
        NSSound.beep()
    }

    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.stopModal()
    }

    @IBAction func cancel(_ sender: Any) {
        close()
        NSApplication.shared.stopModal(withCode: NSApplication.ModalResponse.cancel)
    }


    func log(_ message: String) {
        Async.main {
            self.logText.textStorage?.setAttributedString(
                NSAttributedString(string: self.logText.string + message, attributes: self.attributes))
            self.logText.scrollRangeToVisible(
                NSMakeRange(self.logText.string.count, 0))
        }
    }

    var isCanceled: Bool {
        get {
            return false
        }
    }
}
