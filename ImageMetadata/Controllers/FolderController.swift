//

import AppKit
import RangicCore

extension MainController {

    func initializeDirectoryView(_ folderName: String) {
        rootDirectory = DirectoryTree(parent: nil, folder: folderName)
        folderView.delegate = self
        folderView.dataSource = self
        folderView.deselectAll(nil)
        folderView.reloadData()
        selectDirectoryViewRow(Preferences.lastSelectedFolder)
    }

    func getActiveDirectory() -> String {
        let selectedItem = toTree(folderView.item(atRow: folderView.selectedRow))
        return selectedItem.folder
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        clearAllMarkers()
        let selectedItem = toTree(folderView.item(atRow: folderView.selectedRow))
        Preferences.lastSelectedFolder = selectedItem.folder
        populateImagesView(selectedItem.folder)
    }

    func selectDirectoryViewRow(_ folderName: String) {
        var bestRow = -1
        var exactMatch = false
        var startRow = 0
        var hasMatch = false

        repeat {
            hasMatch = false
            for row in startRow..<folderView.numberOfRows {
                let dt = folderView.item(atRow: row) as! DirectoryTree
                if dt.folder == folderName {
                    bestRow = row
                    exactMatch = true
                    hasMatch = true
                    break
                }

                if folderName.lowercased().hasPrefix(dt.folder.lowercased()) {
                    bestRow = row
                    hasMatch = true
                }
            }

            if bestRow >= 0 {
                if exactMatch {
                    folderView.selectRowIndexes(IndexSet(integer: bestRow), byExtendingSelection: false)
                    folderView.scrollRowToVisible(bestRow)
                } else {
                    folderView?.expandItem(folderView.item(atRow: bestRow))
                    startRow = bestRow
                }
            }
        } while hasMatch && !exactMatch
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if rootDirectory == nil { return 0 }
        return toTree(item).subFolders.count
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return toTree(item).subFolders.count > 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        return toTree(item).subFolders[index]
    }

    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        return toTree(item).relativePath
    }

    func toTree(_ item: Any?) -> DirectoryTree {
        if let dirTree = item as! DirectoryTree? {
            return dirTree
        }

        return rootDirectory!
    }
}
