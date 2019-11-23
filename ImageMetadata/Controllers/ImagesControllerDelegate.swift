//

import Cocoa
import RangicCore
import Async

// Implement NSCollectionViewDelegate for `imageView`
extension MainController {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        setImagesStatus()
        if followSelectionOnMap {
            let mediaData = filteredViewItems[indexPaths.first!.item]
            clearAllMarkers()
            showMediaOnMap([mediaData])
        }
    }
    
    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        setImagesStatus()
    }

    @IBAction func toggleKeywordsFilter(_ sender: Any) {
        applyFilters()
    }

    @IBAction func toggleLocationFilter(_ sender: Any) {
        applyFilters()
    }

    @IBAction func toggleTimestampFilter(_ sender: Any) {
        applyFilters()
    }

    @IBAction func showInAppleMaps(_ sender: Any) {
        launchLocationUrl( { (item: MediaData) -> (String) in
            return "http://maps.apple.com/?ll=\(item.location.latitude),\(item.location.longitude)"
        })
    }
    
    @IBAction func showInGoogleMaps(_ sender: Any) {
        launchLocationUrl( { (item: MediaData) -> (String) in
            return "http://maps.google.com/maps?q=\(item.location.latitude),\(item.location.longitude)"
        })
    }
    
    @IBAction func showInOpenStreetMaps(_ sender: Any) {
        launchLocationUrl( { (item: MediaData) -> (String) in
            return "http://www.openstreetmap.org/?&mlat=\(item.location.latitude)&mlon=\(item.location.longitude)#map=18/\(item.location.latitude)/\(item.location.longitude)"
        })
    }
    
    @IBAction func showInGoogleStreetView(_ sender: Any) {
        launchLocationUrl( { (item: MediaData) -> (String) in
            return "http://maps.google.com/maps?q=&layer=c&cbll=\(item.location.latitude),\(item.location.longitude)&cbp=11,0,0,0,0"
        })
    }
    
    @IBAction func copyLatLon(_ sender: Any) {
        visitFirstSelectedItem( { (item: MediaData) -> () in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("\(item.location.latitude),\(item.location.longitude)", forType: NSPasteboard.PasteboardType.string)
        })
    }
    
    @IBAction func pasteLatLon(_ sender: Any) {
        let mediaItems = selectedMediaItems()
        if mediaItems.count < 1 {
            MainController.showWarning("No items selected, cannot paste location")
            return
        }

        // Ensure lat,lon on clipboard
        var clipboardText: String? = nil
        for item in NSPasteboard.general.pasteboardItems! {
            if let str = item.string(forType: NSPasteboard.PasteboardType(rawValue: "public.utf8-plain-text")) {
                clipboardText = str
                break
            }
        }

        if clipboardText == nil {
            MainController.showWarning("Can't find any text on the clipboard")
            return
        }

        // Expect two doubles, separated by a comma
        let locationTokens = clipboardText!.split(separator: ",")
        if locationTokens.count != 2 {
            MainController.showWarning("Can't find '<lat>,<lon>' in\n '\(clipboardText!)'\nPerhaps the comma is missing.")
            return
        }

        guard let lat = Double(locationTokens[0].trimmingCharacters(in: .whitespaces)), let lon = Double(locationTokens[1].trimmingCharacters(in: .whitespaces)) else {
            MainController.showWarning("Can't parse out '<lat>,<lon>' from\n '\(clipboardText!)'")
            return
        }


        // visit all selected items, apply lat/lon - but don't overwrite
        var filePaths = [String]()
        for item in mediaItems {
            filePaths.append(item.url!.path)
        }
        updateLocations(Location(latitude: lat, longitude: lon), filePaths: filePaths)
    }

    @IBAction func clearLatLon(_ sender: Any) {
        let mediaItems = selectedMediaItems()
        if mediaItems.count < 1 {
            MainController.showWarning("No items selected, cannot clear location")
            return
        }
        let (imagePathList, videoPathList) = separateVideoList(mediaItems)

        Async.background {
            do {
                try ExifToolRunner.clearFileLocations(imagePathList, videoFilePaths: videoPathList)

                for mediaData in mediaItems {
                    mediaData.location = nil
                }

                Async.main {
                    self.reloadExistingMedia()
                }
            } catch let error {
                Async.main {
                    self.reloadExistingMedia()
                    MainController.showWarning("Clearing file locations failed: \(error)")
                }
            }
        }
    }
}
