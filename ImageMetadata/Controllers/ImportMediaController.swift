//

import Cocoa
import RangicCore


struct ImportFileInfo {
    let filename: String
    let yearMonthDay: String

    init(_ filename: String, _ yearMonthDay: String) {
        self.filename = filename
        self.yearMonthDay = yearMonthDay
    }
}

class DateTableEntry {
    var checked = false
    let date: String
    var count: Int = 1
    
    init(_ date: String) {
        self.date = date
    }
}

class ImportMediaController : NSWindowController, NSTableViewDataSource {
    @IBOutlet weak var selectedFolderLabel: NSTextField!
    @IBOutlet weak var folderInfoLabel: NSTextField!
    @IBOutlet weak var dateTable: NSTableView!

    let dateFormatter = DateFormatter()
    var exportsAvailable = [DateTableEntry]()

    // The exported & original files (full paths), indexed by date
    var exportedDateFiles = [String:[String]]()
    var originalDateFiles = [String:[String]]()
    
    func getImportList() -> [DateAndFiles] {
        var importList = [DateAndFiles]()
        for e in exportsAvailable {
            if e.checked {
                importList.append(DateAndFiles(
                    e.date, exportedDateFiles[e.date] ?? [], originalDateFiles[e.date] ?? []))
            }
        }
        
        return importList
    }

    static func create() -> ImportMediaController {
        let controller = ImportMediaController(windowNibName: NSNib.Name(stringLiteral: "ImportMedia"))
        return controller
    }

    override func awakeFromNib() {
        dateFormatter.dateFormat = "yyyy-MM-dd"
        selectedFolderLabel.stringValue = Preferences.lastImportedFolder
        folderInfoLabel.stringValue = ""
        dateTable.dataSource = self
    }

    override func windowDidLoad() {
        populateDateInfo()
    }

    @IBAction func selectExportedFolder(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Choose the exported folder"

        if Preferences.lastImportedFolder.isEmpty {
            
        } else {
            panel.directoryURL = URL(fileURLWithPath: Preferences.lastImportedFolder)
        }

        panel.beginSheetModal(for: self.window!) { response in
            if response == .OK {
                Preferences.lastImportedFolder = panel.url!.path
                self.selectedFolderLabel.stringValue = Preferences.lastImportedFolder
                self.populateDateInfo()
            }
            panel.close()
        }
    }

    @IBAction func cancel(_ sender: Any) {
        close()
        NSApplication.shared.stopModal(withCode: NSApplication.ModalResponse.cancel)
    }

    @IBAction func `import`(_ sender: Any) {
        let anyEnabled = exportsAvailable.filter { $0.checked }.count > 0
        if !anyEnabled {
            MainController.showWarning("No dates have been checked, nothing to import.")
            return
        }

        close()
        NSApplication.shared.stopModal(withCode: NSApplication.ModalResponse.OK)
    }

    func populateDateInfo() {
        if !FileManager.default.fileExists(atPath: Preferences.lastImportedFolder) {
            return
        }

        // Enum files, find unique dates
        // Enum each sibling folder
        //      Complain if exported has item not found in sibling
        //      Count items both in exported & sibling, which match dates from exported
        //  Result is a collection of date strings
        let exportedFolderName = (Preferences.lastImportedFolder as NSString).lastPathComponent
        do {
            let (exportedFiles, exportedDates) = enumFiles(Preferences.lastImportedFolder)
            exportedDateFiles = exportedDates

            let siblings = try FileManager.default.contentsOfDirectory(
                                at: URL(fileURLWithPath: "\(Preferences.lastImportedFolder)/.."),
                                includingPropertiesForKeys: nil)
                .filter { $0.hasDirectoryPath && $0.lastPathComponent != exportedFolderName }

            var siblingFiles = [String:[String:ImportFileInfo]]()
            var siblingDates = [String:[String]]()
            for s in siblings {
                let (files, dates) = enumFiles(s.path)
                siblingFiles[s.lastPathComponent] = files
                for (d, list) in dates {
                    if siblingDates.index(forKey: d) != nil {
                        siblingDates[d]! += list
                    } else {
                        siblingDates[d] = list
                    }
                }
            }
            originalDateFiles = siblingDates

            // Ensure everything in `exported` appears in a sibling
            var originalFilesMissing = [String]()
            for x in exportedFiles {
                var foundMatch = false
                for s in siblingFiles {
                    if s.value.index(forKey: x.key) != nil {
                        foundMatch = true
                        break
                    }
                }
                if !foundMatch {
                    originalFilesMissing.append(x.value.filename)
                }
            }

            // Count the files in the sibling directories for each date:
            //  1. That is a date for exported files
            //  2. OR comprises of ONLY videos in ALL siblings
            var mapDateInfo = [String:DateTableEntry]()
            for d in exportedDates {
                mapDateInfo[d.key] = DateTableEntry(d.key)
                mapDateInfo[d.key]?.count = originalDateFiles[d.key]?.count ?? 0
            }
            for d in originalDateFiles {
                if mapDateInfo.index(forKey: d.key) == nil {
                    var videosOnly = true
                    for f in d.value {
                        let fileExtension = (f as NSString).pathExtension
                        if SupportedMediaTypes.getTypeFromFileExtension(fileExtension) != .video {
                            videosOnly = false
                            break
                        }
                    }
                    if videosOnly {
                        mapDateInfo[d.key] = DateTableEntry(d.key)
                        mapDateInfo[d.key]?.count = d.value.count
                    }
                }
            }
            
            exportsAvailable = mapDateInfo.values.sorted { $0.date < $1.date }
            dateTable.reloadData()

            if !originalFilesMissing.isEmpty {
                let readable = originalFilesMissing.joined(separator: ", ")
                MainController.showWarning("Some original files do NOT have an exported file:\n\(readable)")
            }
        } catch {
            MainController.showWarning("Failed populating date info: \(error)")
        }
    }

    // Return:
    // 1) the filenames without extension (key) and associated date (yyyy-MM-dd format)
    // 2) the date (yyyy-MM-dd format) to the files with that date
    func enumFiles(_ folder: String) -> ([String:ImportFileInfo], [String:[String]]) {
        let repository = FileMediaRepository(autoUpdate: false)
        repository.addFolder(folder, notifyOnLoad: false)

        var files = [String:ImportFileInfo]()
        var dates = [String:[String]]()

        for (_, m) in repository.enumerated() {
            let name = (m.name! as NSString).deletingPathExtension
            let date = dateFormatter.string(from: m.timestamp!)
            files[name] = ImportFileInfo(m.name!, date)
            if dates.index(forKey: date) != nil {
                dates[date]!.append(m.url!.path)
            } else {
                dates[date] = [m.url!.path]
            }
        }

        return (files, dates)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return exportsAvailable.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        switch tableColumn?.identifier.rawValue {
        case "checked":
            return exportsAvailable[row].checked
        case "mediaDate":
            return exportsAvailable[row].date
        case "numFiles":
            return exportsAvailable[row].count
        default:
            Logger.info("value for \(row) - \(tableColumn!.identifier.rawValue)")
            break
        }
        return "Uh-oh"
    }

    @IBAction func onDateCheckClicked(_ sender: Any) {
        exportsAvailable[dateTable.selectedRow].checked = !exportsAvailable[dateTable.selectedRow].checked
    }

    @IBAction func toggleAllDates(_ sender: Any) {
        let anyEnabled = exportsAvailable.filter { $0.checked }.count > 0
        for e in exportsAvailable {
            e.checked = !anyEnabled
        }
        dateTable.reloadData()
    }
}
