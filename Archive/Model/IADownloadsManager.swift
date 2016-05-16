//
//  IADownloadsManager.swift
//  Archive
//
//  Created by Mejdi Lassidi on 5/3/16.
//  Copyright © 2016 Archive. All rights reserved.
//

import Foundation
import Alamofire
import SSZipArchive

class IADownloadsManager {
    static let sharedInstance = IADownloadsManager()
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    struct FileDownloadStatus {
        var file: File?
        var chapter: Chapter?
        var totalBytesRead: Int64?
        var totalBytesExpectedToRead: Int64?
    }
    
    private var filesQueue : Array<FileDownloadStatus>? = []
    
    private var totalProgress: Double? {
        get {
            var totalBytesRead: Int64 = 0
            var totalBytesExpectedToRead: Int64 = 0
            for file in filesQueue! {
                totalBytesRead += file.totalBytesRead!
                totalBytesExpectedToRead += file.totalBytesExpectedToRead!
            }
            return Double(Float(totalBytesRead)/Float(totalBytesExpectedToRead))
        }
    }
    
    func downloadTrigger(chapter: Chapter) {
        if chapter.isDownloaded?.boolValue == true {
        
        }else {
            if let file = chapter.file {
                download(chapter, file: file)
            }
       }
    }
    
    private func download(chapter: Chapter, file: File) {
        let fileStatus = FileDownloadStatus(file: file, chapter: chapter, totalBytesRead: 0, totalBytesExpectedToRead: 0)
        filesQueue?.append(fileStatus)
        let destination = Alamofire.Request.suggestedDownloadDestination(
            directory: .CachesDirectory,
            domain: .UserDomainMask
        )
        let type = chapter.type?.rawValue.lowercaseString
        chapter.markInDownloadingState()
        Alamofire.download(.GET, "https://\(file.server!)\(file.directory!)/\(chapter.subdirectory!)_\(type!).zip", destination: destination)
            .response { request, response, _, error in
                let unzipSucceed = (SSZipArchive.unzipFileAtPath((destination(NSURL(string: "")!, response!).absoluteString as NSString).substringFromIndex(7), toDestination: "\(self.docuementsDirectory())"))
                if unzipSucceed {
                    self.filesQueue?.indexOf({$0.file?.archiveItem?.identifier == file.archiveItem!.identifier && $0.chapter?.name == chapter.name}).map({
                        if let chapter = self.filesQueue![$0].chapter {
                            chapter.markDownloaded()
                        }
                        self.filesQueue!.removeAtIndex($0)
                        if self.filesQueue?.count == 0 {self.appDelegate.downloadProgress = 0}
                        self.appDelegate.downloadDone()
                        NSNotificationCenter.defaultCenter().postNotificationName("\(chapter.name!)_finished", object:  nil)
//                        NSNotificationCenter.defaultCenter().postNotificationName(notificationDownloadedAdded, object: nil)
                        
                    })
                }
            }
            .progress{ bytesRead, totalBytesRead, totalBytesExpectedToRead in
                self.filesQueue?.indexOf({$0.file?.archiveItem!.identifier == file.archiveItem!.identifier && $0.chapter?.name == chapter.name}).map({
                    self.filesQueue![$0].totalBytesRead = totalBytesRead
                    self.filesQueue![$0].totalBytesExpectedToRead = totalBytesExpectedToRead
                    self.appDelegate.downloadProgress = Float(self.totalProgress!)
                    NSNotificationCenter.defaultCenter().postNotificationName("\(chapter.name!)_progress", object:  Double(Float(totalBytesRead)/Float(totalBytesExpectedToRead)))
                    }
                )
        }
        
    }
    
    func getDownloadedChapters()->NSArray? {
        return Chapter.getDownloadedChapters()
    }
    
    func getChaptersInDownloadState() -> NSArray? {
       return  Chapter.getChaptersInDownloadState()
    }
    
    func getDownloadQueue()->[FileDownloadStatus]? {
        return filesQueue
    }
    
    func resumeDownloads() {
        print("cache = \(NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)[0])")
        let chaptersInDownloadState = self.getChaptersInDownloadState()
        for chapter in chaptersInDownloadState as! [Chapter] {
            self.download(chapter, file: chapter.file!)
        }
    }
    
    //MARK: - Helpers
    
    func docuementsDirectory()->String {
        let paths =  NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        return paths[0]
    }
    
    func pathInDownloadChapter(chapter: Chapter) -> String?{
        let cacheDirectoryPath = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)[0]
        return "\(cacheDirectoryPath)/\(chapter.name!)"
    }
}