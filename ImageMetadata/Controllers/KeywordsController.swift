//

import Cocoa

class KeywordsController: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate {
    var collectionView: NSCollectionView? = nil
    var filesAndKeywords: FilesAndKeywords? = nil


    static func initializeView(_ view: NSCollectionView) -> KeywordsController {
        let controller = KeywordsController()
        controller.collectionView = view
        view.dataSource = controller

        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.itemSize = NSSize(width: 180, height: 30)
        flowLayout.sectionInset = NSEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)
        flowLayout.minimumInteritemSpacing = 20.0
        flowLayout.minimumLineSpacing = 20.0
        flowLayout.sectionHeadersPinToVisibleBounds = true
        view.collectionViewLayout = flowLayout

        return controller
    }

    func keywordChanged(_ keyword: String, _ enabled: Bool) {
        if filesAndKeywords != nil {
            if enabled {
                filesAndKeywords?.addKeyword(keyword)
            } else {
                filesAndKeywords?.removeKeyword(keyword)
            }
        }
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return Keywords.sharedInstance.keywords.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {

        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "KeywordsViewItem"), for: indexPath)
        guard let keywordsItem = item as? KeywordsViewItem else { return item }

        keywordsItem.keyword = Keywords.sharedInstance.keywords[indexPath.item]
        return item
    }

    func setKeywords(_ fk: FilesAndKeywords) {
        filesAndKeywords = nil
        for (index, _) in Keywords.sharedInstance.keywords.enumerated() {
            if let viewItem = collectionView?.item(at: index) as! KeywordsViewItem? {
                viewItem.controller = self
                viewItem.stateEnabled = fk.uniqueKeywords.contains(viewItem.keyword!)
            }
        }
        filesAndKeywords = fk
    }

    func getEnabledKeywords() -> [String] {
        var keywords = [String]()
        for (index, k) in Keywords.sharedInstance.keywords.enumerated() {
            if let viewItem = collectionView?.item(at: index) as! KeywordsViewItem? {
                if viewItem.stateEnabled {
                    keywords.append(k)
                }
            }
        }
        return keywords
    }
}
