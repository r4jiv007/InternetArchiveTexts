//
//  IADownloadCollectionVC.swift
//  Archive
//
//  Created by Islam on 5/12/16.
//  Copyright © 2016 Archive. All rights reserved.
//

import UIKit
import CoreData

class IADownloadCollectionVC: IAGenericItemCollectionVC {
    
    var presentationDelegate = IASortPresentationDelgate()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setFetchRequest()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(IADownloadCollectionVC.reload), name: "download_done", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(IADownloadCollectionVC.reload), name: "download_deleted", object: nil)
    }
    
    func reload() {
        performFetch()
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    // MARK: - CollectionView
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> IAGenericItemCollectionCell {
        let cell = super.collectionView(collectionView, cellForItemAtIndexPath: indexPath)
        
        fetchedResultController?.managedObjectContext.performBlock {
            let item = self.fetchedResultController!.objectAtIndexPath(indexPath) as! ArchiveItem
            
            NSOperationQueue.mainQueue().addOperationWithBlock {
                cell.configure(item, type: .Download) {
                    self.showChaptersList(item)
                }
                
                cell.secondActionClosure = {
                    self.presentDetails(item)
                }
            }
        }
        
        return cell
    }
    
    //MARK: - Show Chapters
    
    func showChaptersList(item: ArchiveItem) {
        let chaptersBookmarksVC =  UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("IAChapterBookmarkExploreVC") as! IAChapterBookmarkExploreVC
        chaptersBookmarksVC.transitioningDelegate = presentationDelegate
        chaptersBookmarksVC.item = IAArchiveItem(item:item)
        chaptersBookmarksVC.chapterSelectionHandler = { chapterIndex in
            self.showReader(item, atChapterIndex: chapterIndex)
        }
        chaptersBookmarksVC.bookmarkSelectionHandler = { page in
            self.showReader(item, atPage: page)
        }
        chaptersBookmarksVC.modalPresentationStyle = .Custom
        self.presentViewController(chaptersBookmarksVC, animated: true, completion: nil)
    }
    
    // MARK: - Helpers
    
    func setFetchRequest() {
        let fetchRequest = NSFetchRequest(entityName: "ArchiveItem")
        fetchRequest.predicate = NSPredicate(format: "ANY file.chapters.isDownloaded == YES", argumentArray: nil)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "identifier", ascending: true)]
        
        setFetchRequest(fetchRequest)
    }
    
    var bookDetailsPresentationDelegate = IABookDetailsPresentationDelgate()
    
    private func presentDetails(item: ArchiveItem) {
        let bookDetails = UIStoryboard(name: "BookDetails", bundle: nil).instantiateInitialViewController() as! IABookDetailsVC
        bookDetails.book = IAArchiveItem(item: item)
        if Utils.isiPad() {
            bookDetails.transitioningDelegate = self.bookDetailsPresentationDelegate
            bookDetails.modalPresentationStyle = .Custom
            bookDetails.pushListOnDismiss = {text, type in
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let itemsListVC = storyboard.instantiateViewControllerWithIdentifier("bookListVC") as! IAItemsListVC
                itemsListVC.loadList(text ?? "", type: type)
                self.navigationController?.pushViewController(itemsListVC, animated: true)
            }
            bookDetails.pushReaderOnChapter = {chapterIndex in
                self.showReader(item, atChapterIndex: chapterIndex)
            }
            self.presentViewController(bookDetails, animated: true, completion: nil)
        }else {
            self.navigationController?.pushViewController(bookDetails, animated: true)
        }
    }

    func showReader(item: ArchiveItem, atChapterIndex chapterIndex :Int = -1) {
        let navController = UIStoryboard(name: "Reader",bundle: nil).instantiateInitialViewController() as! UINavigationController
        let bookReader = navController.topViewController as! IAReaderVC
        bookReader.item = IAArchiveItem(item: item)
        bookReader.didGetFileDetailsCompletion = {
            bookReader.setupReaderToChapter(chapterIndex)
        }
        self.presentViewController(navController, animated: true, completion: nil)
    }
    
    func showReader(item: ArchiveItem, atPage page :Page) {
        let navController = UIStoryboard(name: "Reader",bundle: nil).instantiateInitialViewController() as! UINavigationController
        let bookReader = navController.topViewController as! IAReaderVC
        bookReader.item = IAArchiveItem(item: item)
        bookReader.didGetFileDetailsCompletion = {
            bookReader.setupReaderToChapter((item.file?.chapters?.allObjects as! [Chapter]).sort({ $0.name < $1.name}).indexOf(page.chapter!)!){
                let number = (page.number?.intValue)!
                if number != 0 {
                    bookReader.pageNumber = Int(number)
                    bookReader.updateUIAfterPageSeek(true)
                }
            }
        }
        self.presentViewController(navController, animated: true, completion: nil)
    }

}
