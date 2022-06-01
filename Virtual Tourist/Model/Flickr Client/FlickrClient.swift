//
//  FlickrClient.swift
//  Virtual Tourist
//
//  Created by David Hsieh on 12/29/21.
//

import Foundation

class FlickrClient {
    static let apiKey = "4bc772b075293d5248cafaa434fd96d6"
    static let secret = "f9db38cb295189e0"
    static var numPagesAvilable = 1
    static var currentTasks = [URLSessionDataTask]()
    
    enum Endpoints {
        static let searchHost = "https://www.flickr.com/services/"
        static let searchMethod = "rest/?method=flickr.photos.search"
        static let apiKeyString = "api_key=\(FlickrClient.apiKey)"
        static let responseFormat = "&format=json&nojsoncallback=1"
        
        case getPhotos(lat: Double, lon: Double, page: Int)
        case image(String)
        
        var stringValue: String {
            switch self {
            case .getPhotos(let lat, let lon, let page):
                return Endpoints.searchHost + Endpoints.searchMethod + "&" + Endpoints.apiKeyString + "&lat=\(lat)" + "&lon=\(lon)" + "&page=\(page)" + Endpoints.responseFormat
            case .image(let imagePath):
                return "https://live.staticflickr.com/" + imagePath
            }
        }
        
        var url: URL {
            return URL(string: stringValue)!
        }
    }
    
    class func getPhotos(lat: Double, lon: Double, page: Int, completion: @escaping (PhotosInfo?, Error?) -> Void) -> URLSessionDataTask{
        let task = taskForGETRequest(url: Endpoints.getPhotos(lat: lat, lon: lon, page: page).url, responseType: Photos.self) { response, error in
            if let response = response {
                completion(response.photos, nil)
            } else {
                completion(nil, error)
            }
        }
        return task
    }
    
    class func downloadImage(path: String, completion: @escaping (Data?, Error?) -> Void) -> URLSessionDataTask {
        let task = URLSession.shared.dataTask(with: Endpoints.image(path).url) { data, response, error in
            DispatchQueue.main.async {
                completion(data, error)
            }
        }
        task.resume()
        return task
    }
    
    class func taskForGETRequest<ResponseType: Decodable>(url: URL, responseType: ResponseType.Type, completion: @escaping (ResponseType?, Error?) -> Void) -> URLSessionDataTask {
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            let decoder = JSONDecoder()
            do {
                let responseObject = try decoder.decode(responseType.self, from: data)
                DispatchQueue.main.async {
                    completion(responseObject, nil)
                }
            } catch {
                do {
                    let errorResponse = try decoder.decode(FlickrResponse.self, from: data) as Error
                    DispatchQueue.main.async {
                        completion(nil, errorResponse)
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                }
            }
        }
        task.resume()
        
        return task
    }
    
    static func getRandomPage() -> Int {
        print("num pages available: \(FlickrClient.numPagesAvilable)")
        return FlickrClient.numPagesAvilable > 0 ? Int.random(in: 1...FlickrClient.numPagesAvilable) : 1
    }
    
    static func cancelTasks() {
        for task in currentTasks {
            task.cancel()
        }
    }
}
