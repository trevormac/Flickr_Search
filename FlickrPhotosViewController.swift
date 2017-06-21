//
//  FlickrPhotosViewController.swift
//  FlickrSearch
//
//  Created by Trevor MacGregor on 2017-06-14.
//  Copyright © 2017 TeevoCo. All rights reserved.
//

import UIKit

final class FlickrPhotosViewController: UICollectionViewController {
    
    // MARK: - Properties
    fileprivate let reuseIdentifier = "FlickrCell"
    fileprivate let sectionInsets = UIEdgeInsets(top: 50.0, left: 20.0, bottom: 50.0, right: 20.0)
    fileprivate var searches = [FlickrSearchResults]()
    fileprivate let flickr = Flickr()
    fileprivate let itemsPerRow: CGFloat = 3
    fileprivate var selectedPhotos = [FlickrPhoto]()
    fileprivate let shareTextLabel = UILabel()
    
    //largePhotoIndexPath is an optional that will hold the index path of the tapped photo, if there is one
    var largePhotoIndexPath: IndexPath? {
        didSet {
            //Whenever this property gets updated, the collection view needs to be updated. a didSet property observer is the safest place to manage this
            var indexPaths = [IndexPath]()
            if let largePhotoIndexPath = largePhotoIndexPath {
                indexPaths.append(largePhotoIndexPath as IndexPath)
            }
            if let oldValue = oldValue {
                indexPaths.append(oldValue as IndexPath)
            }
            //this will animate any changes to the collection view performed inside the block. You want it to reload the affected cells.
            collectionView?.performBatchUpdates({
                self.collectionView?.reloadItems(at: indexPaths)
            }) { completed in
                //Once the animated update has finished, it’s a nice touch to scroll the enlarged cell to the middle of the screen
        if let largePhotoIndexPath = self.largePhotoIndexPath {
        self.collectionView?.scrollToItem(
        at: largePhotoIndexPath as IndexPath,
        at: .centeredVertically,
        animated: true)        }
        }
     }
  
   }
    
    //In this observer, you toggle the multiple selection status of the collection view, clear any existing selection and empty the selected photos array. You also update the bar button items to include and update the shareTextLabel
    var sharing: Bool = false {
        didSet{
            collectionView?.allowsMultipleSelection = sharing
            collectionView?.selectItem(at: nil, animated: true, scrollPosition: UICollectionViewScrollPosition())
            selectedPhotos.removeAll(keepingCapacity: false)
            
            guard let sharebutton = self.navigationItem.rightBarButtonItems?.first else {
                return
            }
            guard sharing else {
                navigationItem.setRightBarButtonItems([sharebutton], animated: true)
                return
            }
            if let _ = largePhotoIndexPath {
                largePhotoIndexPath = nil
            }
            updateSharedPhotoCount()
            let sharingDetailItem = UIBarButtonItem(customView: shareTextLabel)
            navigationItem.setRightBarButtonItems([sharebutton,sharingDetailItem], animated: true)
        }
        
    }
  
    //MARK:Share button
    @IBAction func share(_ sender: UIBarButtonItem) {
        guard !searches.isEmpty else {
            return
        }
        guard !selectedPhotos.isEmpty else {
            return
        }
        guard sharing else {
            return
        }
        
        //creates an array of UIImage objects from the FlickrPhoto‘s thumbnails. The UIImage array is much more convenient, as we can simply pass it to a UIActivityViewController. The UIActivityViewController will show the user any image sharing services or actions available on the device: iMessage, Mail, Print, etc. You simply present your UIActivityViewController from within a popover (because this is an iPad app), and let the user take care of the rest:
        var imageArray = [UIImage]()
        for selectedPhoto in selectedPhotos {
            if let thumbnail = selectedPhoto.thumbnail {
                imageArray.append(thumbnail)
                
            }
        }
        print("Share button clicked")
        if !imageArray.isEmpty {
            let shareScreen = UIActivityViewController(activityItems: imageArray, applicationActivities: nil)
            shareScreen.completionWithItemsHandler = { _ in
                self.sharing = false
            }
            let popoverPresentationController = shareScreen.popoverPresentationController
            popoverPresentationController?.barButtonItem = sender
            popoverPresentationController?.permittedArrowDirections = .any
            present(shareScreen, animated: true, completion: nil)
        }

    }
    
    
}
//MARK: Private

//convenience method that gets a specific photo related to an indexpath in the collection view
private extension FlickrPhotosViewController {
    func photoForIndexPath(indexPath: IndexPath) -> FlickrPhoto {
        return searches[(indexPath as NSIndexPath).section].searchResults[(indexPath as NSIndexPath).row]
    }
    
    
    func updateSharedPhotoCount() {
        shareTextLabel.textColor = themeColour
        shareTextLabel.text = "\(selectedPhotos.count) photos selected"
        shareTextLabel.sizeToFit()
    }
    
}

// MARK: - UICollectionViewDataSource
extension FlickrPhotosViewController {
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return searches.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return searches[section].searchResults.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        //kind parameter is supplied by the layout object and indicates which sort of supplementary view is being asked for:
        switch kind {
        case UICollectionElementKindSectionHeader:
            //header view is dequeued using the identifier added in the storyboard:
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "FlickrPhotoHeaderView", for: indexPath) as! FlickrPhotoHeaderView
            headerView.label.text = searches[(indexPath as NSIndexPath).section].searchTerm
            return headerView
        default:
            //An assert is placed here to make it clear to other developers (including future you!) that you’re not expecting to be asked for anything other than a header view
            assert(false, "Unexpected element kind")
       }
    }
    
    override func collectionView(_ collectionView: UICollectionView,
                                 cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: reuseIdentifier, for: indexPath) as! FlickrPhotoCell
        var flickrPhoto = photoForIndexPath(indexPath: indexPath)
        
        //Always stop the activity spinner – you could be reusing a cell that was previously loading an image
        cell.activityIndicator.stopAnimating()
        
        //if you’re not looking at the large photo, just set the thumbnail and return
        guard indexPath == largePhotoIndexPath else {
            cell.imageView.image = flickrPhoto.thumbnail
            return cell
        }
        
        //If the large image is already loaded, set it and return
        guard flickrPhoto.largeImage == nil else {
            cell.imageView.image = flickrPhoto.largeImage
            return cell
        }
        
        //By this point, you want the large image, but it doesn’t exist yet. Set the thumbnail image and start the spinner going. The thumbnail will stretch until the download is complete
        cell.imageView.image = flickrPhoto.thumbnail
        cell.activityIndicator.startAnimating()
        
        //Ask for the large image from Flickr. This loads the image asynchronously and has a completion block
        flickrPhoto.loadLargeImage {loadedFlickrPhoto, error in
            //The load has finished, so stop the spinner
            cell.activityIndicator.stopAnimating()
            
            //If there was an error or no photo was loaded, there’s not much you can do. So return out
            guard loadedFlickrPhoto.largeImage != nil && error == nil else {
                return
            }
        
            //Check that the large photo index path hasn’t changed while the download was happening, and retrieve whatever cell is currently in use for that index path (it may not be the original cell, since scrolling could have happened) and set the large image.
            if let cell = collectionView.cellForItem(at: indexPath) as? FlickrPhotoCell,
                indexPath == self.largePhotoIndexPath  {
                cell.imageView.image = loadedFlickrPhoto.largeImage
            }
        }
        
        return cell
    }
    
    //removed the moving item from it’s spot in the results array, and then reinserted it into the array in its new position:
    override func collectionView(_ collectionView: UICollectionView,
                                 moveItemAt sourceIndexPath: IndexPath,
                                 to destinationIndexPath: IndexPath) {
        
        var sourceResults = searches[(sourceIndexPath as NSIndexPath).section].searchResults
        let flickrPhoto = sourceResults.remove(at: (sourceIndexPath as NSIndexPath).row)
        
        var destinationResults = searches[(destinationIndexPath as NSIndexPath).section].searchResults
        destinationResults.insert(flickrPhoto, at: (destinationIndexPath as NSIndexPath).row)
    }

    
}


//MARK: UICollectionView Delegate
//If the tapped cell is already the large photo, set the largePhotoIndexPath property to nil, otherwise set it to the index path the user just tapped. This will then call the property observer you added earlier and cause the collection view to reload the affected cell(s).
extension FlickrPhotosViewController {
    
    override func collectionView(_ collectionView: UICollectionView,
                                 shouldSelectItemAt indexPath: IndexPath) -> Bool {
        
        //This will allow selection in sharing mode
        guard !sharing else {
            return true
        }
        
        largePhotoIndexPath = largePhotoIndexPath == indexPath ? nil : indexPath
        return false
    }
    
    //This method allows adding selected photos to the shared photos array and updates the shareTextLabel:
    override func collectionView(_ collectionView: UICollectionView,
                                 didSelectItemAt indexPath: IndexPath) {
        guard sharing else {
            return
        }
        
        let photo = photoForIndexPath(indexPath: indexPath)
        selectedPhotos.append(photo)
        updateSharedPhotoCount()
    }
    
    //This method removes a photo from the shared photos array and updates the shareTextLabel:
     func collectionView(collectionView: UICollectionView,
                                 didDeselectItemAtIndexPath indexPath: IndexPath) {
        
        guard sharing else {
            return
        }
        
        let photo = photoForIndexPath(indexPath: indexPath)
        
        if let index = selectedPhotos.index(of: photo) {
            selectedPhotos.remove(at: index)
            updateSharedPhotoCount()
        }
    }


}

extension FlickrPhotosViewController: UICollectionViewDelegateFlowLayout {
    
    //responsible for telling the layout the size of a given cell
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,sizeForItemAt indexPath: IndexPath) -> CGSize {
        // New code
        if indexPath == largePhotoIndexPath {
            let flickrPhoto = photoForIndexPath(indexPath: indexPath)
            var size = collectionView.bounds.size
            size.height -= topLayoutGuide.length
            size.height -= (sectionInsets.top + sectionInsets.right)
            size.width -= (sectionInsets.left + sectionInsets.right)
            return flickrPhoto.sizeToFillWidthOfSize(size)
        }

        //here we work out the total amount of space taken up by padding. There will be n + 1 evenly sized spaces, where n is the number of items in the row. The space size can be taken from the left section inset. Subtracting this from the view’s width and dividing by the number of items in a row gives you the width for each item. You then return the size as a square:
        
        let paddingSpace = sectionInsets.left * (itemsPerRow + 1)
        let availableWidth = view.frame.width - paddingSpace
        let widthPerItem = availableWidth / itemsPerRow
        
        return CGSize(width: widthPerItem, height: widthPerItem)
    }
    
    // returns the spacing between the cells, headers, and footers:
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return sectionInsets
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return sectionInsets.left
    }
    
    
    
}

extension FlickrPhotosViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        //After adding an activity view, use the Flickr wrapper class to search Flickr for photos that match the given search term asynchronously. When the search completes, the completion block will be called with a the result set of FlickrPhoto objects, and an error (if there was one).
        
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        textField.addSubview(activityIndicator)
        activityIndicator.frame = textField.bounds
        activityIndicator.startAnimating()
        
        flickr.searchFlickrForTerm(textField.text!) {
            results, error in
            
            activityIndicator.removeFromSuperview()
            
            if let error = error {
                
                print("Error searching: \(error)")
                return
            }
            if let results = results {
                
                //results get logged and added to the front of the searches array
                print("Found \(results.searchResults.count) matching\(results.searchTerm)")
                self.searches.insert(results, at: 0)
                
                self.collectionView?.reloadData()
            }
        }
        textField.text = nil
        textField.resignFirstResponder()
        return true
    }
}



