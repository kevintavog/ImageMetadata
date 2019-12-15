//

import AppKit
import Quartz
import WebKit

import RangicCore

import Async

class MainController : NSWindowController, NSOutlineViewDelegate, ImagesCollectionViewDelegate, NSOutlineViewDataSource, NSCollectionViewDataSource, NSCollectionViewDelegate, WKNavigationDelegate, WKScriptMessageHandler {

    @IBOutlet weak var folderView: NSOutlineView!

    @IBOutlet weak var imagesView: NSCollectionView!
    @IBOutlet weak var imagesStatus: NSTextField!
    @IBOutlet weak var imagesSlider: NSSlider!
    @IBOutlet weak var locationState: NSButton!
    @IBOutlet weak var keywordState: NSButton!
    @IBOutlet weak var timestampState: NSButton!
    @IBOutlet weak var mapView: MapWebView!

    @IBOutlet weak var menuFollowSelectionOnMap: NSMenuItem!
    @IBOutlet weak var menuRegularMap: NSMenuItem!
    @IBOutlet weak var menuDarkMap: NSMenuItem!
    @IBOutlet weak var menuSatelliteMap: NSMenuItem!
    @IBOutlet weak var menuOpenStreetMaps: NSMenuItem!

    @IBOutlet weak var tabView: NSTabView!
    @IBOutlet weak var locationTabItem: NSTabViewItem!
    @IBOutlet weak var keywordsTabItem: NSTabViewItem!

    @IBOutlet weak var keywordsView: NSCollectionView!


    var rootDirectory: DirectoryTree?
    var followSelectionOnMap = true
    var mediaProvider = MediaProvider(autoUpdate: false)
    var filteredViewItems = [MediaData]()
    var keywordsController: KeywordsController? = nil
    var selectedKeywords = FilesAndKeywords()
    var quickLookItems = [MediaData]()


    override func awakeFromNib() {
        initializeMapView()
        initializeImagesView()
        keywordsController = KeywordsController.initializeView(keywordsView)


        #if DEBUG
        initializeDirectoryView(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures/To Server/Radish").path)
        #else
        initializeDirectoryView(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures/master").path)
        #endif
    }

    @IBAction func activateKeywords(_ sender: Any) {
        tabView.selectTabViewItem(keywordsTabItem)
    }

    @IBAction func activateLocation(_ sender: Any) {
        tabView.selectTabViewItem(locationTabItem)
    }

    @IBAction func `import`(_ sender: Any) {
        let controller = ImportMediaController.create()
        let result = NSApplication.shared.runModal(for: controller.window!)
        if result == NSApplication.ModalResponse.OK {
            let importList = controller.getImportList()

            let logController = LogResultsController.create(header: "Importing media")
            Async.background {
                ImportMedia.run(self.rootDirectory!.folder, importList, logController)
                Async.main {
                    logController.operationCompleted()
                    self.rootDirectory?.reload()
                    self.folderView.reloadData()
                }
            }

            NSApplication.shared.runModal(for: logController.window!)
        }
    }

    static func showWarning(_ message: String) {
        Logger.error(message)
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = NSAlert.Style.warning
        alert.addButton(withTitle: "Close")
        alert.runModal()
    }
}
