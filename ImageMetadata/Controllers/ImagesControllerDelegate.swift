//

import Cocoa
import RangicCore
import Async

// Implement NSCollectionViewDelegate for `imageView`
extension MainController {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        selectionChanged(indexPaths, true)
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        selectionChanged(indexPaths, false)
    }

    func selectionChanged(_ indexPaths: Set<IndexPath>, _ didSelect: Bool) {
        setImagesStatus()
        
        if didSelect {
            if followSelectionOnMap {
                let mediaData = filteredViewItems[indexPaths.first!.item]
                clearAllMarkers()
                showMediaOnMap([mediaData])
            }
        }

        do {
            if try selectedKeywords.save() {
                reloadMediaDataItems(selectedKeywords.mediaItems)
            }
        } catch let error {
            Logger.error("Failed saving keywords: \(error)")
            MainController.showWarning("Failed saving keywords: \(error)")
        }

        selectedKeywords = FilesAndKeywords(mediaItems: selectedMediaItems())
        keywordsController?.setKeywords(selectedKeywords)
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
        visitFirstSelectedItem( { (mediaItem: MediaData) -> () in
            self.requireLocation(mediaItem, { (item: MediaData) -> () in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(item.location.latitude),\(item.location.longitude)", forType: NSPasteboard.PasteboardType.string)
            })
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
                    self.reloadExistingFolder()
                }
            } catch let error {
                Async.main {
                    self.reloadExistingFolder()
                    MainController.showWarning("Clearing file locations failed: \(error)")
                }
            }
        }
    }

    @IBAction func setFileDateToMetadataDate(_ sender: Any) {
        let mediaItems = selectedMediaItems()
        if mediaItems.count < 1 {
            MainController.showWarning("No items selected, cannot set file dates")
            return
        }

        Async.background {
            for item in mediaItems {
                let _ = item.setFileDateToExifDate()
            }

            Async.main {
                self.reloadExistingFolder()
            }
        }
    }

    @IBAction func showInFinder(_ sender: Any) {
        visitFirstSelectedItem( { (item: MediaData) -> () in
            NSWorkspace.shared.selectFile(item.url!.path, inFileViewerRootedAtPath: "")
        })
    }

    @IBAction func convertVideo(_ sender: Any) {
        let mediaItems = selectedMediaItems()
        if mediaItems.count < 1 {
            MainController.showWarning("No items selected, cannot convert videos")
            return
        }

        // Convert items that are videos that haven't already been converted
        let videos = mediaItems.filter( { $0.type == .video && !$0.name.hasSuffix("_V.MP4") } )
        if videos.count < 1 {
            MainController.showWarning("No unconverted videos selected, nothing to do")
            return
        }

        let folder = self.getActiveDirectory()
        let controller = LogResultsController.create(header: "Convert video")
        Async.background {
            for m in videos {
                let rotationOption = self.getRotationOption(m)

                let sourceName = "\(folder)/\(m.name!)"
                let destinationName = "\(folder)/\(m.nameWithoutExtension)_V.MP4"
                controller.log("convert \(sourceName) -> \(destinationName)\n")
                HandBrakeRunner.convertVideo(sourceName, destinationName, rotationOption, controller)
            }

            Async.main {
                controller.operationCompleted()
                self.reloadExistingFolder()
            }
        }

        NSApplication.shared.runModal(for: controller.window!)
    }

    func getRotationOption(_ mediaData: MediaData) -> String {
        if let rotation = mediaData.rotation {
            switch rotation {
            case 90:
                return "--rotate=4"
            case 180:
                return "--rotate=3"
            case 270:
                return "--rotate=7"
            case 0:
                return ""
            default:
                Logger.warn("Unhandled rotation \(mediaData.rotation!)")
                return ""
            }
        }
        return ""
    }

}
