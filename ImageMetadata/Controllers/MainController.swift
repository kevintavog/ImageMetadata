//

import AppKit
import Quartz
import WebKit

import RangicCore

class MainController : NSWindowController, NSOutlineViewDelegate, NSOutlineViewDataSource, NSCollectionViewDataSource, NSCollectionViewDelegate, WKNavigationDelegate, WKScriptMessageHandler {
    
    var rootDirectory: DirectoryTree?


    @IBOutlet weak var folderView: NSOutlineView!

    @IBOutlet weak var imagesView: NSCollectionView!
    @IBOutlet weak var imagesStatus: NSTextField!
    @IBOutlet weak var imagesSlider: NSSlider!
    @IBOutlet weak var locationState: NSButton!
    @IBOutlet weak var keywordState: NSButton!
    @IBOutlet weak var timestampState: NSButton!
    @IBOutlet weak var mapView: MapWebView!

    var followSelectionOnMap = true
    @IBOutlet weak var menuFollowSelectionOnMap: NSMenuItem!
    @IBOutlet weak var menuRegularMap: NSMenuItem!
    @IBOutlet weak var menuDarkMap: NSMenuItem!
    @IBOutlet weak var menuSatelliteMap: NSMenuItem!
    @IBOutlet weak var menuOpenStreetMaps: NSMenuItem!
    
    @IBOutlet weak var tabView: NSTabView!
    @IBOutlet weak var locationTabItem: NSTabViewItem!
    @IBOutlet weak var keywordsTabItem: NSTabViewItem!
    

    var mediaProvider = MediaProvider()
    var filteredViewItems = [MediaData]()


    override func awakeFromNib() {
        initializeMapView()
        initializeImagesView()


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

    static func showWarning(_ message: String) {
        Logger.error(message)
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = NSAlert.Style.warning
        alert.addButton(withTitle: "Close")
        alert.runModal()
    }
}
