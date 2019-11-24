//

import Cocoa
import RangicCore

class KeywordsViewItem: NSCollectionViewItem {
    @IBOutlet weak var button: NSButton!
    var enabled = false
    let enabledColor = NSColor.controlAccentColor.cgColor
    let disabledColor = NSColor.controlColor.cgColor
    var controller: KeywordsController? = nil


    var stateEnabled: Bool {
        set {
            button.state = newValue ? NSControl.StateValue.on : NSControl.StateValue.off
            enabled = newValue
            view.layer?.backgroundColor = newValue ? enabledColor : disabledColor
//            button.cell?.controlView?.layer?.backgroundColor = newValue ? enabledColor : disabledColor
            controller?.keywordChanged(keyword!, newValue)
        }
        get {
//            return button.state == NSControl.StateValue.on
            return enabled
        }
    }

    var keyword: String? {
        didSet {
            button.title = keyword!
        }
    }

    @IBAction func onClick(_ sender: Any) {
        stateEnabled = !stateEnabled
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = disabledColor
//        button.cell?.controlView?.wantsLayer = true
//        button.cell?.controlView?.layer?.backgroundColor = disabledColor
        (button.cell as? NSButtonCell)?.showsStateBy = .pushInCellMask
    }
}
