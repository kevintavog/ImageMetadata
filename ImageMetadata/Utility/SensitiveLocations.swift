//

import RangicCore
import SwiftyJSON

class SensitiveLocations {
    let SensitiveDistanceInMeters: Double = 50


    static var sharedInstance: SensitiveLocations {
        struct _Singleton {
            static let instance = SensitiveLocations()
        }
        return _Singleton.instance
    }

    fileprivate(set) var locations = [Location]()


    func isSensitive(_ location: Location) -> Bool {
        for loc in locations {
            if loc.metersFrom(location) < SensitiveDistanceInMeters {
                return true
            }
        }
        return false
    }

    fileprivate func locationToDictionary(_ location: Location) -> Dictionary<String, AnyObject> {
        return [
            "latitude" : location.latitude as AnyObject,
            "longitude" : location.longitude as AnyObject]
    }

    fileprivate var fullLocationFilename: String { return Preferences.preferencesFolder.stringByAppendingPath("rangic.PeachMetadata.sensitive.locations") }


    fileprivate init() {
        if let data = NSData(contentsOfFile: fullLocationFilename) {
            if let json = try? JSON(data:NSData(data: data as Data) as Data) {
                var rawLocationList = [Location]()
                for (_,subjson):(String,JSON) in json {
                    let latitude = subjson["latitude"].doubleValue
                    let longitude = subjson["longitude"].doubleValue

                    rawLocationList.append(Location(latitude: latitude, longitude: longitude))
                }

                updateLocations(rawLocationList)
            }
        }
    }

    fileprivate func updateLocations(_ rawList: [Location]) {
        locations = rawList
    }
}
