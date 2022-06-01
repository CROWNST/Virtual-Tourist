//
//  Info.swift
//  Virtual Tourist
//
//  Created by David Hsieh on 12/29/21.
//

import Foundation

struct PhotosInfo: Codable {
    let pages: Int
    let photo: [PhotoInfo]
}
