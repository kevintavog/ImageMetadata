//
//

import Cocoa
import RangicCore

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!

    override init() {
        super.init()
        
        Logger.configure()
        Preferences.setMissingDefaults()
        ReverseNameLookupProvider.set(host: Preferences.baseLocationLookup)
        SupportedMediaTypes.includeRawImages = true
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }
}

