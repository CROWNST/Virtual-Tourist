//
//  FlickrResponse.swift
//  Virtual Tourist
//
//  Created by David Hsieh on 12/29/21.
//

import Foundation

struct FlickrResponse: Codable {
    let stat: String
    let code: Int
    let message: String
}

extension FlickrResponse: LocalizedError {
    var errorDescription: String? {
        return message
    }
}
