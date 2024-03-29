//

import Cocoa
import Quartz
import RangicCore
import Async

// Implement NSCollectionViewDelegate for `imageView`
extension MainController: QLPreviewPanelDataSource, QLPreviewPanelDelegate {
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

    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        return filteredViewItems[indexPath.item].url! as NSURL
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

    @IBAction func removeDuplicateKeywords(_ sender: Any) {
        let mediaItems = selectedMediaItems()
        if mediaItems.count < 1 {
            MainController.showWarning("No items selected")
            return
        }

        let controller = LogResultsController.create(header: "Removing duplicate keywords")
        Async.background {
            for m in mediaItems {
                if let keywords = m.keywords {
                    let uniqueKeywords: Set = Set(keywords.map { $0 })
                    if uniqueKeywords.count != keywords.count {
                        controller.log("Fixing \(m.name!)\n")
                        do {
                            try ExifToolRunner.setKeywords([m.url!.path], keywords: Array(uniqueKeywords))
                            m.reload()
                        } catch {
                            controller.log("Failed setting keywords for \(m.name!): \(error)")
                        }
                    }
                }
            }

            Async.main {
                controller.operationCompleted()
                self.reloadExistingFolder()
            }
        }

        NSApplication.shared.runModal(for: controller.window!)
    }

    @IBAction func showInFinder(_ sender: Any) {
        visitFirstSelectedItem( { (item: MediaData) -> () in
            NSWorkspace.shared.selectFile(item.url!.path, inFileViewerRootedAtPath: "")
        })
    }

    func doubleClicked(item: IndexPath) {
        if imagesView.selectionIndexPaths.count > 0 {
            viewMedia(self)
        }
    }

    @IBAction func viewMedia(_ sender: Any) {
        let mediaItems = selectedMediaItems()
        var url: URL? = nil

        if mediaItems.count == 0 {
            url = filteredViewItems.first?.url
        } else {
            url = mediaItems.first?.url
        }

        if let realUrl = url {
            if NSWorkspace.shared.open(realUrl) == false {
                MainController.showWarning("Failed opening file: '\(realUrl.path)'")
            }
        }
    }

    @IBAction func resolveAllPlacenames(_ sender: Any) {
        let mediaItems = filteredViewItems
        if mediaItems.count < 1 {
            MainController.showWarning("No items, nothing to do")
            return
        }

        let controller = LogResultsController.create(header: "Resolving placenames")
        Async.background {
            for m in mediaItems {
                if let location = m.location {
                    controller.log("\(m.name!) -> ")
                    let name = location.placenameAsString(.sites)
                    controller.log("\(name)")
                } else {
                    controller.log("\(m.name!) -> < does not have a location >")
                }
                controller.log("\n")
            }

            Async.main {
                controller.operationCompleted()
            }
        }

        NSApplication.shared.runModal(for: controller.window!)
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
                let rotationOption = HandBrakeRunner.getRotationOption(m.rotation)

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

    @IBAction func adjustTime(_ sender: Any) {
        let mediaItems = selectedMediaItems()
        if mediaItems.count < 1 {
            MainController.showWarning("No items selected")
            return
        }

        let controller = AdjustDateController.create(media: mediaItems)
        let result = NSApplication.shared.runModal(for: controller.window!)
        if result == .OK {
            let (hours, minutes, seconds) = controller.offsets()
            Async.background {
                do {
                    let (imagePathList, videoPathList) = self.separateVideoList(mediaItems)
                    try ExifToolRunner.adjustMetadataDates(imagePathList, videoFilePaths: videoPathList, hours: hours, minutes: minutes, seconds: seconds)

                    for m in mediaItems {
                        m.reload()
                    }

                    let _ = self.mediaProvider.setFileDatesToExifDates(mediaItems)
                    Async.main {
                        self.reloadMediaDataItems(mediaItems)
                    }
                } catch let error {
                    Logger.error("Setting dates failed: \(error)")

                    Async.main {
                        MainController.showWarning("Setting dates failed: \(error)")
                    }
                }
            }
        }
    }

    @IBAction func setTime(_ sender: Any) {
        visitFirstSelectedItem( { (mediaItem: MediaData) -> () in
            let controller = SetDateController.create(file: mediaItem.fileTimestamp!, metadata: mediaItem.timestamp!)
            let result = NSApplication.shared.runModal(for: controller.window!)
            if result == .OK {
                if let newDate = controller.newDate() as NSDate? {
                    Async.background {
                        do {
                            let (imagePathList, videoPathList) = self.separateVideoList([mediaItem.url!.path])
                            try ExifToolRunner.setMetadataDates(imagePathList, videoFilePaths: videoPathList, newDate: newDate)
                            mediaItem.reload()
                            let _ = self.mediaProvider.setFileDatesToExifDates([mediaItem])

                            Async.main {
                                self.reloadMediaDataItems([mediaItem])
                            }
                        } catch let error {
                            Logger.error("Setting dates failed: \(error)")

                            Async.main {
                                MainController.showWarning("Setting dates failed: \(error)")
                            }
                        }
                    }
                }
            }
        })
    }

    @IBAction func copyMetadata(_ sender: Any) {
        visitFirstSelectedItem( { (mediaItem: MediaData) -> () in

            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.canCreateDirectories = false
            panel.allowsMultipleSelection = false
            panel.title = "Choose the metadata destination"

            panel.directoryURL = mediaItem.url!.deletingLastPathComponent()

            panel.beginSheetModal(for: self.window!) { response in
                if response == .OK {
                    let destPath = panel.url!.path
                    Async.background {
                        do {
                            _ = try ExifToolRunner.copyMetadata(mediaItem.url!.path, destPath)
                            if let destMediaItem = self.mediaProvider.itemFromFilePath(destPath) {
                                destMediaItem.reload()
                                Async.main {
                                    self.reloadMediaDataItems([destMediaItem])
                                }
                            }
                        } catch let error {
                            Logger.error("Copying metadata failed: \(error)")

                            Async.main {
                                MainController.showWarning("Copying metadata failed: \(error)")
                            }
                        }
                    }
                    Logger.info("copy metadata; source=\(mediaItem.url!.path); dest=\(destPath)")
                }
                panel.close()
            }
        })
    }

    @IBAction func quickLook(_ sender: Any) {
        quickLookItems = selectedMediaItems()
        if quickLookItems.count < 1 {
            MainController.showWarning("No items selected.")
            return
        }

        if let panel = QLPreviewPanel.shared() {
            panel.delegate = self
            panel.dataSource = self
            panel.makeKeyAndOrderFront(self)
        }
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return quickLookItems.count
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return quickLookItems[index].url as QLPreviewItem
    }
}
