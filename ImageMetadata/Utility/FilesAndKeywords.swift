//

import RangicCore

open class FilesAndKeywords {
    public let mediaItems: [MediaData]
    open fileprivate(set) var uniqueKeywords: [String]
    fileprivate var addedKeywords = Set<String>()
    fileprivate var removedKeywords = Set<String>()


    public init() {
        mediaItems = [MediaData]()
        uniqueKeywords = [String]()
    }

    public init(mediaItems: [MediaData]) {
        self.mediaItems = mediaItems

        var unique = Set<String>()
        for m in mediaItems {
            if let mediaKeywords = m.keywords {
                for k in mediaKeywords {
                    unique.insert(k)
                }
            }
        }

        uniqueKeywords = unique.map({$0}).sorted()
    }

    open func addKeyword(_ keyword: String) {
        if !uniqueKeywords.contains(keyword) {
            addedKeywords.insert(keyword)
            removedKeywords.remove(keyword)
            uniqueKeywords.append(keyword)
            uniqueKeywords = uniqueKeywords.sorted()
        }
    }

    open func removeKeyword(_ keyword: String) {
        if let index = uniqueKeywords.firstIndex(of: keyword) {
            addedKeywords.remove(keyword)
            removedKeywords.insert(keyword)
            uniqueKeywords.remove(at: index)
        }
    }

    // Returns true there were changes, false if no changes. Throws if saving fails.
    open func save() throws -> Bool {
        // Do nothing if there have been no changes.
        if mediaItems.count == 0 || (removedKeywords.count == 0 && addedKeywords.count == 0) {
            return false
        }

        var filePaths = [String]()
        for m in mediaItems {
            filePaths.append(m.url!.path)
        }

        let ret = try ExifToolRunner.updateKeywords(filePaths, addedKeywords: addedKeywords.map({$0}), removedKeywords: removedKeywords.map({$0}))

        addedKeywords.removeAll()
        removedKeywords.removeAll()

        if ret {
            for m in mediaItems {
                m.reload()
            }
        }

        return ret
    }
}
