//

import AppKit
import RangicCore

class AdjustDateController: NSWindowController, NSTableViewDataSource {
    
    @IBOutlet weak var hoursLabel: NSTextField!
    @IBOutlet weak var hoursStepper: NSStepper!
    @IBOutlet weak var minutesLabel: NSTextField!
    @IBOutlet weak var minutesStepper: NSStepper!
    @IBOutlet weak var secondsLabel: NSTextField!
    @IBOutlet weak var secondsStepper: NSStepper!
    @IBOutlet weak var table: NSTableView!
    @IBOutlet weak var okButton: NSButton!
    
    let dateFormatter = DateFormatter()
    fileprivate var media: [MediaData] = []


    func offsets() -> (Int, Int, Int) {
        return (hoursStepper.integerValue, minutesStepper.integerValue, secondsStepper.integerValue)
    }

    static func create(media: [MediaData]) -> AdjustDateController {
        let controller = AdjustDateController(windowNibName: NSNib.Name(stringLiteral: "AdjustDate"))
        controller.media = media.sorted { $0.timestamp! < $1.timestamp! }
        return controller
    }

    override func awakeFromNib() {
        dateFormatter.dateFormat = "HH:mm:ss"
        hoursLabel.intValue = 0
        minutesLabel.intValue = 0
        secondsLabel.intValue = 0
    }

    @IBAction func cancel(_ sender: Any) {
        close()
        NSApplication.shared.stopModal(withCode: NSApplication.ModalResponse.cancel)
    }

    @IBAction func adjustTime(_ sender: Any) {
        close()
        NSApplication.shared.stopModal(withCode: NSApplication.ModalResponse.OK)
    }

    @IBAction func hoursChanged(_ sender: NSStepper) {
        hoursLabel.integerValue = sender.integerValue
        table.reloadData()
    }

    @IBAction func minutesChanged(_ sender: NSStepper) {
        minutesLabel.integerValue = sender.integerValue
        table.reloadData()
    }

    @IBAction func secondsChanged(_ sender: NSStepper) {
        secondsLabel.integerValue = sender.integerValue
        table.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return media.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        switch tableColumn?.identifier.rawValue {
        case "Filename":
            return media[row].name
        case "Current":
            return dateFormatter.string(from: media[row].timestamp)
        case "Adjusted":
            return dateFormatter.string(from: adjustedTime(media[row].timestamp))
        default:
            Logger.info("value for \(row) - \(tableColumn!.identifier.rawValue)")
            break
        }
        return ""
    }
    
    func adjustedTime(_ date: Date) -> Date {
        let seconds = (hoursStepper.integerValue * 60 * 60) + (minutesStepper.integerValue * 60) + secondsStepper.integerValue
        return Date(timeInterval: Double(seconds), since: date)
    }
}
