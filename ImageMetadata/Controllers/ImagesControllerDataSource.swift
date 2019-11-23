//

import AppKit
import Cocoa
import RangicCore


// Implement NSCollectionViewDataSource for `imageView`
extension MainController {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredViewItems.count
    }

    func collectionView(_ itemForRepresentedObjectAtcollectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {

        let item = imagesView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ImagesViewItem"), for: indexPath)
        guard let imagesItem = item as? ImagesViewItem else { return item }

        imagesItem.mediaData = filteredViewItems[indexPath.item]
        return item
    }


}

