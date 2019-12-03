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

    @IBAction func createFolder(_ sender: Any) {
        let tree = toTree(folderView.item(atRow: folderView.selectedRow))
        let parent = tree.folder
        let alert = NSAlert()
        alert.messageText = "Enter a folder name to create as a child of\n\(parent)"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let txt = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        txt.stringValue = ""
        alert.accessoryView = txt
        alert.window.initialFirstResponder = txt

        if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
            let childFolder = txt.stringValue
            if childFolder != "" {
                do {
                    try FileManager.default.createDirectory(atPath: "\(parent)/\(childFolder)", withIntermediateDirectories: false)
                    tree.reload()
                    folderView.reloadData()
                } catch {
                    MainController.showWarning("Failed creating '\(childFolder)': \(error)")
                }
            }
        }
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
