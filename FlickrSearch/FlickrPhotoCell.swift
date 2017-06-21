//
//  FlickrPhotoCell.swift
//  FlickrSearch
//
//  Created by Trevor MacGregor on 2017-06-14.
//  Copyright © 2017 TeevoCo. All rights reserved.
//

import UIKit

class FlickrPhotoCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
 
    
// give the cell control of its background colour
//MARK:Properties
    override var isSelected: Bool {
        didSet {
            imageView.layer.borderWidth = isSelected ? 10:0
        }
    }
//MARK: View Life Cycle
    override func awakeFromNib() {
        super.awakeFromNib()
        imageView.layer.borderColor = themeColour.cgColor
        isSelected = false
    }
    
}
