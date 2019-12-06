//

import Cocoa
import RangicCore

protocol ImagesCollectionViewDelegate {
    func doubleClicked(item: IndexPath)
}

class ImagesCollectionView : NSCollectionView {
    var anchorIndex: IndexPath? = nil

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)

        let shiftDown = event.modifierFlags.contains(.shift)
        let commandDown = event.modifierFlags.contains(.command)
        let clickedItem = indexPathForItem(at: convert(event.locationInWindow, from: nil))

        if event.clickCount > 1 {
            anchorIndex = nil
            (self.delegate as? ImagesCollectionViewDelegate)?.doubleClicked(item: clickedItem!)
            return
        }

        if !shiftDown && !commandDown {
            anchorIndex = clickedItem
        } else if shiftDown && !commandDown {
            if let anchor = anchorIndex, let clicked = clickedItem {
                let start = min(anchor.item, clicked.item)
                let end = max(anchor.item, clicked.item)
                var selected = Set<IndexPath>()
                for idx in start...end {
                    selected.insert(IndexPath(indexes: [0, idx]))
                }
                selectionIndexPaths = selected
            }
        }
    }
}
