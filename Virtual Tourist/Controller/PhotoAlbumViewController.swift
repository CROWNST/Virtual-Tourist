//
//  PhotoAlbumViewController.swift
//  Virtual Tourist
//
//  Created by David Hsieh on 12/28/21.
//

import Foundation
import UIKit
import CoreData
import MapKit

class PhotoAlbumViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, MKMapViewDelegate, UICollectionViewDelegateFlowLayout {
    
    var pin: Pin!
    
    var dataController:DataController!
    
    var fetchedResultsController:NSFetchedResultsController<Photo>!
    
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var label: UILabel!
    
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    
    @IBOutlet weak var newCollectionButton: UIBarButtonItem!
    
    @IBAction func newCollectionButtonPressed(_ sender: Any) {
        let randomPage = FlickrClient.getRandomPage()
        setUpData(page: randomPage)
    }
    
    fileprivate func setupFetchedResultsController() {
        let fetchRequest:NSFetchRequest<Photo> = Photo.fetchRequest()
        let predicate = NSPredicate(format: "pin == %@", pin)
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = []
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: "\(pin!)-photos")
        fetchedResultsController.delegate = self

        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
    }
    
    fileprivate func setUpMap() {
        let center = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
        let span = MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        let region = MKCoordinateRegion(center: center, span: span)
        let annotation = MKPointAnnotation()
        annotation.coordinate = center
        mapView.addAnnotation(annotation)
        mapView.setRegion(region, animated: true)
    }
    
    fileprivate func setUpData(page: Int) {
        label.isHidden = false
        label.text = "Loading Images"
        resetData()
        let task = FlickrClient.getPhotos(lat: pin.latitude, lon: pin.longitude, page: page, completion: handleGetPhotosResponse(photosInfo:error:))
        FlickrClient.currentTasks.append(task)
    }
    
    fileprivate func handleGetPhotosResponse(photosInfo: PhotosInfo?, error: Error?) {
        if photosInfo != nil {
            if photosInfo!.photo.isEmpty{
                label.text = "No Images"
            } else {
                label.isHidden = true
            }
            PhotoInfoModel.photoInfo = photosInfo!.photo
            collectionView.reloadData()
            FlickrClient.numPagesAvilable = photosInfo!.pages
            for photoInfo in PhotoInfoModel.photoInfo {
                let imagePath = "\(photoInfo.server)/\(photoInfo.id)_\(photoInfo.secret).jpg"
                let task = FlickrClient.downloadImage(path: imagePath, completion: handleDownloadImageResponse(data:error:))
                FlickrClient.currentTasks.append(task)
            }
        } else {
            label.text = "No Images"
        }
    }
    
    fileprivate func handleDownloadImageResponse(data: Data?, error: Error?) {
        if (data != nil) {
            let photo = Photo(context: self.dataController.viewContext)
            photo.image = data
            photo.pin = self.pin
            try? self.dataController.viewContext.save()
            try? fetchedResultsController.performFetch()
        }
        PhotoInfoModel.numImageDownloadAttempts += 1
        if PhotoInfoModel.numImageDownloadAttempts == PhotoInfoModel.photoInfo.count {
            collectionView.reloadData()
            newCollectionButton.isEnabled = true
            FlickrClient.currentTasks.removeAll()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        label.isHidden = true
        collectionView.delegate = self
        collectionView.dataSource = self
        mapView.delegate = self
        newCollectionButton.isEnabled = false
        setUpMap()
        setupFetchedResultsController()
        if fetchedResultsController.fetchedObjects!.isEmpty {
            setUpData(page: 1)
        } else {
            newCollectionButton.isEnabled = true
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        FlickrClient.cancelTasks()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        fetchedResultsController = nil
    }
    
    fileprivate func resetData() {
        for photo in fetchedResultsController.fetchedObjects! {
            dataController.viewContext.delete(photo)
            try? dataController.viewContext.save()
        }
        try? fetchedResultsController.performFetch()
        PhotoInfoModel.photoInfo = [PhotoInfo]()
        PhotoInfoModel.numImageDownloadAttempts = 0
        newCollectionButton.isEnabled = false
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if fetchedResultsController.fetchedObjects!.count > 0 {
            return fetchedResultsController.fetchedObjects!.count
        }
        return PhotoInfoModel.photoInfo.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "image", for: indexPath) as! CustomCollectionViewCell
        if (PhotoInfoModel.numImageDownloadAttempts == PhotoInfoModel.photoInfo.count) {
            let photo = fetchedResultsController.object(at: indexPath)
            let image = UIImage(data: photo.image!)
            cell.imageView.image = image
        } else {
            let image = UIImage(named: "VirtualTourist_76")
            cell.imageView.image = image
        }

        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if (PhotoInfoModel.numImageDownloadAttempts == PhotoInfoModel.photoInfo.count)
        {
            let photo = fetchedResultsController.object(at: indexPath)
            dataController.viewContext.delete(photo)
            try? dataController.viewContext.save()
            try? fetchedResultsController.performFetch()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let space: CGFloat = 3.0
        let smallSide = min(view.frame.size.width, view.frame.size.height)
        let dimension = (smallSide - (2 * space)) / 3.0
        flowLayout.minimumInteritemSpacing = space
        return CGSize(width: dimension, height: dimension)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reuseId = "pin"
        
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView

        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = false
            pinView!.pinTintColor = .red
        }
        else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
}

extension PhotoAlbumViewController:NSFetchedResultsControllerDelegate {
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .delete:
            collectionView.deleteItems(at: [indexPath!])
            break
        default:
            break
        }
    }
}
