//

import Cocoa
import WebKit

import Async
import RangicCore


extension MainController {
    func initializeMapView() {
        mapView.configuration.userContentController.add(self, name: "callback")
        mapView.configuration.userContentController.add(self, name: "showDetailedPlacename")

        mapView.navigationDelegate = self
        mapView.load(URLRequest(url: URL(fileURLWithPath: Bundle.main.path(forResource: "map", ofType: "html")!)))
//        mapView.enableDragAndDrop(updateLocations)
    }

    func clearAllMarkers() {
        let _ = mapView.invokeMapScript("removeAllMarkers()")
    }

    @IBAction func showAllMarkers(_ sender: Any) {
        Logger.info("Show markers on map")
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
        case "showDetailedPlacename":
            Logger.error("show detailed placename: \(message.body)")
            let dict = message.body as? NSDictionary
            let lat = dict!["lat"] as? Double ?? 0
            let lon = dict!["lon"] as? Double ?? 0
            mapShowDetailedPlacename(lat, lon)
            break
        default:
            Logger.error("unhandled web message: \(message.name); \(message.body)")
            break
        }
    }

    func mapShowDetailedPlacename(_ lat: Double, _ lon: Double) {
        let location = Location(latitude: lat, longitude: lon)
        let locationJsonStr = location.toDms().replacingOccurrences(of: "\"", with: "\\\"")
        let message = "Looking up \(locationJsonStr)"
        let _ = mapView.invokeMapScript("setPopup([\(lat), \(lon)], \"\(message)\")")
        Async.background {
            let placename = location.placenameAsString(.none)
            Async.main {
                self.mapView.invokeMapScript("setPopup([\(lat), \(lon)], \"\(placename)\")")
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

}
