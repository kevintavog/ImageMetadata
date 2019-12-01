//

import AppKit


class SetDateController: NSWindowController {
    
    @IBOutlet weak var fileDateLabel: NSTextField!
    @IBOutlet weak var metadataDateLabel: NSTextField!
    @IBOutlet weak var newDateField: NSTextField!
    @IBOutlet weak var okButton: NSButton!

    fileprivate var fileDate: Date!
    fileprivate var metadataDate: Date!
    let dateFormatter = DateFormatter()

    func newDate() -> Date? {
        return dateFormatter.date(from: newDateField.stringValue)
    }

    static func create(file: Date, metadata: Date) -> SetDateController {
        let controller = SetDateController(windowNibName: NSNib.Name(stringLiteral: "SetDate"))
        controller.fileDate = file
        controller.metadataDate = metadata
        return controller
    }

    override func awakeFromNib() {
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        fileDateLabel.stringValue = dateFormatter.string(from: fileDate)
        metadataDateLabel.stringValue = dateFormatter.string(from: metadataDate)
    }

    @IBAction func useFile(_ sender: Any) {
        newDateField.stringValue = dateFormatter.string(from: fileDate)
    }

    @IBAction func useMetadata(_ sender: Any) {
        newDateField.stringValue = dateFormatter.string(from: metadataDate)
    }

    @IBAction func onCancel(_ sender: Any) {
        newDateField.stringValue = ""
        close()
        NSApplication.shared.stopModal(withCode: NSApplication.ModalResponse.cancel)
    }

    @IBAction func onSetDate(_ sender: Any) {
        let date = dateFormatter.date(from: newDateField.stringValue)
        if date == nil {
            let alert = NSAlert()
            alert.messageText = "Invalid date format: '\(newDateField.stringValue)'; must match '\(dateFormatter.dateFormat!)'"
            alert.alertStyle = NSAlert.Style.warning
            alert.addButton(withTitle: "Close")
            alert.runModal()
            return
        }

        close()
        NSApplication.shared.stopModal(withCode: NSApplication.ModalResponse.OK)
    }
}
