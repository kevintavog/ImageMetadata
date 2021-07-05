//

import Cocoa
import WebKit

import Async
import RangicCore


extension MainController {
    func initializeMapView() {
        mapView.configuration.userContentController.add(self, name: "markerClicked")
        mapView.configuration.userContentController.add(self, name: "showDetailedPlacename")
        mapView.configuration.userContentController.add(self, name: "updateMarker")

        mapView.navigationDelegate = self
        mapView.load(URLRequest(url: URL(fileURLWithPath: Bundle.main.path(forResource: "map", ofType: "html")!)))
        mapView.enableDragAndDrop(updateLocations)
    }

    func clearAllMarkers() {
        let _ = mapView.invokeMapScript("removeAllMarkers()")
    }

    @IBAction func showAllMarkers(_ sender: Any) {
        clearAllMarkers()
        var mediaItems = selectedMediaItems()
        if mediaItems.count == 0 {
            mediaItems = filteredViewItems
        }

        showMediaOnMap(mediaItems)
    }
    
    @IBAction func followSelectionOnMap(_ sender: Any) {
        followSelectionOnMap = !followSelectionOnMap
        menuFollowSelectionOnMap?.state = followSelectionOnMap ? .on : .off
    }
    
    @IBAction func showRegularMap(_ sender: Any) {
        menuRegularMap?.state = .on
        menuDarkMap?.state = .off
        menuSatelliteMap?.state = .off
        menuOpenStreetMaps?.state = .off
        let _ = mapView.invokeMapScript("setMapLayer()")
    }
    
    @IBAction func showDarkMap(_ sender: Any) {
        menuRegularMap?.state = .off
        menuDarkMap?.state = .on
        menuSatelliteMap?.state = .off
        menuOpenStreetMaps?.state = .off
        let _ = mapView.invokeMapScript("setDarkLayer()")
    }
    
    @IBAction func showSatelliteMap(_ sender: Any) {
        menuRegularMap?.state = .off
        menuDarkMap?.state = .off
        menuSatelliteMap?.state = .on
        menuOpenStreetMaps?.state = .off
        let _ = mapView.invokeMapScript("setSatelliteLayer()")
    }
    
    @IBAction func showOpenStreetMaps(_ sender: Any) {
        menuRegularMap?.state = .off
        menuDarkMap?.state = .off
        menuSatelliteMap?.state = .off
        menuOpenStreetMaps?.state = .on
        let _ = mapView.invokeMapScript("setOpenStreetMapLayer()")
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


    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        mapView.mapInitialized = true
        setSensitiveLocationsOnMap()
    }

    func setSensitiveLocationsOnMap() {
        let _ = mapView.invokeMapScript("removeAllSensitiveLocations()")

        for loc in SensitiveLocations.sharedInstance.locations {
            let _ = mapView.invokeMapScript("addSensitiveLocation([\(loc.latitude), \(loc.longitude)], \(Int(SensitiveLocations.sharedInstance.SensitiveDistanceInMeters)))")
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "markerClicked":
            let params = message.body as? NSDictionary
            mapMarkerClicked(params!["path"] as? String ?? "")
            break
        case "showDetailedPlacename":
            let dict = message.body as? NSDictionary
            let lat = dict!["lat"] as? Double ?? 0
            let lon = dict!["lon"] as? Double ?? 0
            mapShowDetailedPlacename(lat, lon)
            break
        case "updateMarker":
            let dict = message.body as? NSDictionary
            // id, lat, lon
            let id = dict!["id"] as? String ?? ""
            let lat = dict!["lat"] as? Double ?? 0
            let lon = dict!["lon"] as? Double ?? 0
            mapUpdateMarker(id, lat, lon)
            break
        default:
            Logger.error("unhandled web message: \(message.name); \(message.body)")
            break
        }
    }

    func mapMarkerClicked(_ path: String) {
        for (index,m) in filteredViewItems.enumerated() {
            if m.url!.path == path {
                imagesView.deselectAll(nil)
                var items = Set<IndexPath>()
                items.insert(IndexPath(item: index, section: 0))
                imagesView.selectItems(at: items, scrollPosition: .centeredVertically)
                break
            }
        }
    }
    
    func mapShowDetailedPlacename(_ lat: Double, _ lon: Double) {
        let location = Location(latitude: lat, longitude: lon)
        let locationJsonStr = location.toDms().replacingOccurrences(of: "\"", with: "\\\"")
        let message = "Looking up \(locationJsonStr)..."
        let _ = mapView.invokeMapScript("setPopup([\(lat), \(lon)], \"\(message)\")")
        Async.background {
            let fullname = location.placenameAsString(.none)
            let sites = location.asPlacename()?.name(.sites) ?? ""
            Async.main {
                let _ = self.mapView.invokeMapScript("setPopup([\(lat), \(lon)], \"\(sites) <br/> <br/> \(fullname)\")")
            }
        }
    }

    func mapUpdateMarker(_ id: String, _ lat: Double, _ lon: Double) {
        for m in filteredViewItems {
            if String(getId(m)) == id {
                Logger.info("Update \(m.url!.path) to \(lat),\(lon)")
                updateLocations(Location(latitude: lat, longitude: lon), filePaths: [m.url!.path])
                break
            }
        }
    }
    
    func showMediaOnMap(_ mediaItems: [MediaData]) {
        var minLat = 90.0
        var maxLat = -90.0
        var minLon = 180.0
        var maxLon = -180.0

        var numberLocations = 0
        for m in mediaItems {
            if let location = m.location {
                numberLocations += 1
                minLat = min(minLat, location.latitude)
                maxLat = max(maxLat, location.latitude)
                minLon = min(minLon, location.longitude)
                maxLon = max(maxLon, location.longitude)
            }
        }

        if numberLocations == 0 {
            return
        }
        else if numberLocations == 1 {
            // Don't completely zoom in for a single image
            minLat -= 0.0015
            maxLat += 0.0015
            minLon -= 0.0015
            maxLon += 0.0015
        }

        let _ = mapView.invokeMapScript("fitToBounds([[\(minLat), \(minLon)],[\(maxLat), \(maxLon)]])")

        for m in mediaItems {
            if let location = m.location {
                let tooltip = "\(m.name!)\\n\(m.keywordsString())"
                let _ = mapView.invokeMapScript("addMarker(\"\(m.url!.path)\", '\(getId(m))', [\(location.latitude), \(location.longitude)], \"\(tooltip)\")")
            }
        }
    }

    func getId(_ mediaData: MediaData) -> Int {
        return mediaData.url!.hashValue
    }

    func setFileLocation(_ filePaths: [String], location: Location) {
        if filePaths.count < 1 {
            Logger.warn("no files to update, no locations being updated")
            return
        }

        let (imagePathList, videoPathList) = separateVideoList(filePaths)

        Async.background {
            do {
                try ExifToolRunner.updateFileLocations(imagePathList, videoFilePaths: videoPathList, location: location)

                for file in filePaths {
                    if let mediaData = self.mediaProvider.itemFromFilePath(file) {
                        mediaData.location = location
                    }
                }

                Async.main {
                    self.reloadExistingFolder()
                }

            } catch let error {
                Logger.error("Setting file location failed: \(error)")

                Async.main {
                    self.reloadExistingFolder()
                    MainController.showWarning("Setting file location failed: \(error)")
                }
            }
        }
    }

    func updateLocations(_ location: Location, filePaths: [String]) {
        var updateList = [String]()
        var skipList = [String]()
        for file in filePaths {
            if let mediaItem = mediaProvider.itemFromFilePath(file) {
                if mediaItem.location != nil && filePaths.count > 1 {
                    skipList.append(file)
                } else {
                    updateList.append(file)
                }
            } else {
                Logger.warn("Unable to find entry for \(file)")
            }
        }

        // Update file locations...
        setFileLocation(updateList, location: location)

        if skipList.count > 0 {
            Async.main {
                MainController.showWarning("Some files were not updated due to existing locations: \(skipList.joined(separator: ", "))")
            }
        }
    }


}
