//

import RangicCore

class Preferences : BasePreferences {
    static fileprivate let BaseLocationLookupKey = "BaseLocationLookup"
    static fileprivate let PlacenameLevelKey = "PlacenameLevel"
    static fileprivate let LastSelectedFolderKey = "LastSelectedFolder"
    static fileprivate let LastImportedFolderKey = "LastImportedFolder"
    static fileprivate let LastDevImportedFolderKey = "LastDevImportedFolder"


    enum PlacenameLevel: Int {
        case short = 1, medium = 2, long = 3
    }


    static func setMissingDefaults() {
        setDefaultValue("http://jupiter/reversenamelookup", key: BaseLocationLookupKey)
        setDefaultValue(PlacenameLevel.medium.rawValue, key: PlacenameLevelKey)
    }

    static var baseLocationLookup: String {
        get { return stringForKey(BaseLocationLookupKey) }
        set { super.setValue(newValue, key: BaseLocationLookupKey) }
    }

    static var placenameLevel: PlacenameLevel {
        get { return PlacenameLevel(rawValue: intForKey(PlacenameLevelKey))! }
        set { super.setValue(newValue.rawValue, key: PlacenameLevelKey) }
    }

    static var placenameFilter: PlaceNameFilter {
        switch placenameLevel {
        case .short:
            return .standard
        case .medium:
            return .sitesNoCountry
        case .long:
            return .detailed
        }
    }

    static var lastSelectedFolder : String {
        get { return stringForKey(LastSelectedFolderKey) }
        set { super.setValue(newValue, key: LastSelectedFolderKey) }
    }

    static var lastImportedFolder : String {
        get { return stringForKey(importedFolderKey) }
        set { super.setValue(newValue, key: importedFolderKey) }
    }

    private static var importedFolderKey: String {
        get {
            #if DEBUG
            return LastDevImportedFolderKey
            #else
            return LastImportedFolderKey
            #endif
        }
    }

    static var preferencesFolder: String {
        return FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].path.stringByAppendingPath("Preferences")
    }
}
