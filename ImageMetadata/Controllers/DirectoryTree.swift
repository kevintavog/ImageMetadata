import Foundation
import RangicCore


class DirectoryTree {
    let folder: String
    let relativePath: String
    fileprivate var _subFolders: [DirectoryTree]?


    init(parent: DirectoryTree!, folder: String) {
        self.folder = folder
        if parent == nil {
            relativePath = ""
        } else {
            relativePath = folder.relativePathFromBase(parent.folder)
        }
    }

    func reload() {
        populateChildren()
    }

    var subFolders: [DirectoryTree] {
        if _subFolders == nil {
            populateChildren()
        }
        return _subFolders!
    }

    fileprivate func populateChildren() {
        var folderEntries = [DirectoryTree]()

        if FileManager.default.fileExists(atPath: folder) {
            if let files = getFiles(folder) {
                for f in files {
                    var isFolder: ObjCBool = false
                    if FileManager.default.fileExists(atPath: f.path, isDirectory:&isFolder) && isFolder.boolValue {
                        folderEntries.append(DirectoryTree(parent: self, folder: f.path))
                    }
                }
            }
        }

        _subFolders = folderEntries
    }

    fileprivate func getFiles(_ folderName: String) -> [URL]? {
        do {
            let list = try FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: folderName),
                includingPropertiesForKeys: nil,
                options:FileManager.DirectoryEnumerationOptions.skipsHiddenFiles)
            return list.sorted { $0.absoluteString < $1.absoluteString }
        }
        catch let error {
            Logger.error("Failed getting files in \(folderName): \(error)")
            return nil
        }
    }
}

