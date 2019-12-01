//

import Cocoa
import RangicCore
import Async


public enum LocationStatus {
    case missingLocation
    case sensitiveLocation
    case goodLocation
}

public enum DateStatus {
    case goodDate
    case mismatchedDate
}

public enum KeywordStatus {
    case noKeyword
    case hasKeyword
}


// Updates the UI for `imageView`, an NSCollectionView
extension MainController {
    static fileprivate let missingAttrs = [
        NSAttributedString.Key.foregroundColor : NSColor(deviceRed: 0.0, green: 0.7, blue: 0.7, alpha: 1.0),
        NSAttributedString.Key.font : NSFont.labelFont(ofSize: 14)

    ]
    static fileprivate let badDataAttrs = [
        NSAttributedString.Key.foregroundColor : NSColor.orange,
        NSAttributedString.Key.font : NSFont.labelFont(ofSize: 14)
    ]


    func initializeImagesView() {
        imagesView.dataSource = self
        imagesView.delegate = self

        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.itemSize = NSSize(width: ImagesViewItem.maxThumbnailPixelSize, height: ImagesViewItem.maxThumbnailPixelSize + 30)
        flowLayout.sectionInset = NSEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)
        flowLayout.minimumInteritemSpacing = 20.0
        flowLayout.minimumLineSpacing = 20.0
        flowLayout.sectionHeadersPinToVisibleBounds = true
        imagesView.collectionViewLayout = flowLayout
        imagesView.wantsLayer = true
        imagesView.layer?.backgroundColor = NSColor.alternatingContentBackgroundColors[0].cgColor

        setImagesStatus()
    }

    func reloadMediaDataItems(_ mediaItems: [MediaData]) {
        let selection = imagesView.selectionIndexPaths
        let urls = mediaItems.map { $0.url }
        var refreshList = Set<IndexPath>()
        for index in 0..<filteredViewItems.count {
            if let viewItem = imagesView.item(at: index) as? ImagesViewItem {
                if urls.contains(viewItem.mediaData?.url) {
                    refreshList.insert(IndexPath(item: index, section: 0))
                }
            }
        }

        if refreshList.count > 0 {
            imagesView.reloadItems(at: refreshList)
        }
        imagesView.selectionIndexPaths = selection
    }

    func reloadExistingFolder() {
        let selection = imagesView.selectionIndexPaths
        mediaProvider.refresh()
        applyFilters()
        imagesView.selectionIndexPaths = selection
        setImagesStatus()
    }

    func populateImagesView(_ folder: String) {
        mediaProvider.clear()
        mediaProvider.addFolder(folder)
        applyFilters()
        setImagesStatus()
    }

    func isFilterActive() -> Bool {
        return locationState.state != .off
            || timestampState.state != .off
            || keywordState.state != .off
    }

    func applyFilters() {
        filteredViewItems.removeAll()
        for (_, m) in mediaProvider.enumerated() {
            if isFilterActive() {
                if locationState.state != .off {
                    if let location = m.location {
                        if SensitiveLocations.sharedInstance.isSensitive(location) {
                            filteredViewItems.append(m)
                            continue
                        }
                    } else {
                        filteredViewItems.append(m)
                        continue
                    }
                }

                if timestampState.state != .off {
                    if m.doFileAndExifTimestampsMatch() == false {
                        filteredViewItems.append(m)
                        continue
                    }
                }

                if keywordState.state != .off {
                    if m.keywords == nil || m.keywords?.count == 0 {
                        filteredViewItems.append(m)
                    }
                }
            } else {
                filteredViewItems.append(m)
            }
        }

        imagesView.reloadData()
    }
    
    func setImagesStatus() {
        if imagesView.selectionIndexPaths.count == 1 {
            let index = imagesView.selectionIndexPaths.first!.item
            setSingleItemStatus(filteredViewItems[index])
        } else {
            setMultiItemStatus(filteredViewItems, filesMessage: "files")
        }

        setImagesState()
    }

    func setMultiItemStatus(_ mediaItems: [MediaData], filesMessage: String) {
        var allKeywords = Set<String>()
        for media in mediaItems {
            if let mediaKeywords = media.keywords {
                for k in mediaKeywords {
                    allKeywords.insert(k)
                }
            }
        }

        let keywordsString = allKeywords.joined(separator: ", ")
        imagesStatus.stringValue = "keywords: \(keywordsString)"
    }

    func setSingleItemStatus(_ media: MediaData) {
        var allKeywords = Set<String>()
        if let mediaKeywords = media.keywords {
            for k in mediaKeywords {
                allKeywords.insert(k)
            }
        }

        var locationString = media.locationString()
        var keywordsString = media.keywordsString()
        if media.keywords == nil || media.keywords.count == 0 {
            keywordsString = "< no keywords >"
        } else {
            keywordsString = media.keywords.joined(separator: ", ")
        }

        if media.location != nil && media.location.hasPlacename() {
            locationString = media.location.placenameAsString(Preferences.placenameFilter)
        }
        imagesStatus.stringValue = "\(media.name!); \(locationString); \(keywordsString)"

        if let location = media.location {
            if !location.hasPlacename() {
                // There's a location, but the placename hasn't been resolved yet
                Async.background {
                    let placename = media.location.placenameAsString(Preferences.placenameFilter)
                    Async.main {
                        self.imagesStatus.stringValue = "\(media.name!); \(placename); \(keywordsString)"
                    }
                }
            }
        }
    }

    func setImagesState() {
        var numberMissingLocation = 0
        var numberWithSensitiveLocation = 0
        var numberWithMismatchedDate = 0
        var numberMissingKeyword = 0

        for media in filteredViewItems {
            if let location = media.location {
                if SensitiveLocations.sharedInstance.isSensitive(location) {
                    numberWithSensitiveLocation += 1
                }

            } else {
                numberMissingLocation += 1
            }

            if media.keywords == nil {
                numberMissingKeyword += 1
            }

            if media.doFileAndExifTimestampsMatch() == false {
                numberWithMismatchedDate += 1
            }
        }

        let mediaCount = filteredViewItems.count

        if numberWithSensitiveLocation > 0 {
            setLocationState(numberWithSensitiveLocation, status: .sensitiveLocation)
        }
        else if numberMissingLocation > 0 {
            setLocationState(numberMissingLocation, status: .missingLocation)
        } else {
            setLocationState(mediaCount, status: .goodLocation)
        }

        if numberWithMismatchedDate > 0 {
            setTimestampState(numberWithMismatchedDate, status: .mismatchedDate)
        } else {
            setTimestampState(mediaCount, status: .goodDate)
        }

        if numberMissingKeyword > 0 {
            setKeywordState(numberMissingKeyword, status: .noKeyword)
        } else {
            setKeywordState(mediaCount, status: .hasKeyword)
        }
    }

    func setLocationState(_ count: Int, status: LocationStatus) {
        let message = String(count)
        var imageName = "location"
        if status == .sensitiveLocation {
            locationState.attributedTitle = NSMutableAttributedString(string: message, attributes: MainController.badDataAttrs)
            imageName = "locationBad"
        } else if status == .missingLocation {
            locationState.attributedTitle = NSMutableAttributedString(string: message, attributes: MainController.missingAttrs)
            imageName = "locationMissing"
        } else {
            locationState.title = message
        }

        locationState.image = NSImage(imageLiteralResourceName: imageName)
    }

    func setTimestampState(_ count: Int, status: DateStatus) {
        let message = String(count)
        var imageName = "timestamp"
        if status == .mismatchedDate {
            timestampState.attributedTitle = NSMutableAttributedString(string: message, attributes: MainController.badDataAttrs)
            imageName = "timestampBad"
        } else {
            timestampState.title = message
        }

        timestampState.image = NSImage(imageLiteralResourceName: imageName)
    }

    func setKeywordState(_ count: Int, status: KeywordStatus) {
        let message = String(count)
        var imageName = "keyword"
        if status == .noKeyword {
            keywordState.attributedTitle = NSMutableAttributedString(string: message, attributes: MainController.missingAttrs)
            imageName = "keywordMissing"
        } else {
            keywordState.title = message
        }

        keywordState.image = NSImage(imageLiteralResourceName: imageName)
    }

    func visitFirstSelectedItem(_ visit: @escaping ( _ mediaItem: MediaData ) -> ()) {
        let mediaItems = selectedMediaItems()
        if mediaItems.count != 1 {
            MainController.showWarning("Only 1 file can be selected, there are \(mediaItems.count) selected")
            return
        }

        visit(mediaItems.first!)
    }

    func requireLocation(_ mediaItem: MediaData, _ visit: @escaping ( _ mediaItem: MediaData ) -> ()) {
        if mediaItem.location != nil {
            visit(mediaItem)
        } else {
            MainController.showWarning("This item has no location info:\n \(mediaItem.url!.path)")
        }

    }
    
    func launchLocationUrl(_ getUrl: @escaping ( _ mediaItem: MediaData ) -> (String)) {
        visitFirstSelectedItem( { (mediaItem: MediaData) -> () in
            self.requireLocation(mediaItem, { (item: MediaData) -> () in
                let url = getUrl(item)
                Logger.info("Launching \(url)")
                NSWorkspace.shared.open(URL(string: url)!)
            })
        })
    }

    func hasSelection() -> Bool {
        return imagesView.selectionIndexPaths.count > 0
    }

    func selectedMediaItems() -> [MediaData] {
        var mediaItems = [MediaData]()
        for index in imagesView.selectionIndexPaths {
            mediaItems.append(filteredViewItems[index.item])
        }
        return mediaItems
    }

    @IBAction func viewMedia(_ sender: Any) {
        let mediaItems = selectedMediaItems()
        if mediaItems.count != 1 {
            Logger.info("Only 1 file can be opened, there are \(mediaItems.count) selected")
            return
        }

        if NSWorkspace.shared.open(mediaItems.first!.url!) == false {
            MainController.showWarning("Failed opening file: '\(mediaItems.first!.url!.path)'")
        }
    }

    func separateVideoList(_ filePaths: [String]) -> (imagePathList:[String], videoPathList:[String]) {
        var mediaItems = [MediaData]()
        for path in filePaths {
            if let item = mediaProvider.itemFromFilePath(path) {
                mediaItems.append(item)
            }
        }
        return separateVideoList(mediaItems)
    }


    func separateVideoList(_ mediaItems: [MediaData]) -> (imagePathList:[String], videoPathList:[String]) {
        var imagePathList = [String]()
        var videoPathList = [String]()

        for mediaData in mediaItems {
            if let mediaType = mediaData.type {
                switch mediaType {
                case SupportedMediaTypes.MediaType.image:
                    imagePathList.append(mediaData.url.path)
                case SupportedMediaTypes.MediaType.video:
                    videoPathList.append(mediaData.url.path)
                default:
                    Logger.warn("Ignoring unknown file type: \(mediaData.url.path)")
                }
            }
        }

        return (imagePathList, videoPathList)
    }

}
