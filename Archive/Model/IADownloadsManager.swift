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

class IADownloadsManager: NSObject {
    static let sharedInstance = IADownloadsManager()
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    struct FileDownloadStatus {
        var file: IAFile?
        var chapter: IAChapter?
        var totalBytesRead: Int64?
        var totalBytesExpectedToRead: Int64?
        var request: Request
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
    
    dynamic var downloadProgress: Double = 0
    
    func downloadTrigger(chapter: IAChapter) {
        if chapter.isDownloaded() {
            deleteChapter(chapter)
        }else {
            if let file = chapter.file {
                download(chapter, file: file)
            }
       }
    }
    
    
    func cancelDownload(chapter: IAChapter) {
        self.filesQueue?.indexOf({$0.file?.archiveItem!.identifier == chapter.file!.archiveItem!.identifier && $0.chapter?.name == chapter.name}).map({
            self.filesQueue![$0].request.cancel()
            let managedContext = CoreDataStackManager.sharedManager.managedObjectContext
            let myfile = File.createFile(chapter.file!, managedObjectContext: managedContext)
            let myChapter = Chapter.createChapter(chapter, file: myfile!)
            myChapter!.markDownloaded(false)
            NSNotificationCenter.defaultCenter().postNotificationName("\(chapter.name!)_deleted", object:  nil)
            self.filesQueue![$0].totalBytesRead = 0
            self.downloadProgress = self.totalProgress!
            self.filesQueue!.removeAtIndex($0)
        })
    }
    
    private func download(chapter: IAChapter, file: IAFile) {
        let destination = Alamofire.Request.suggestedDownloadDestination(
            directory: .CachesDirectory,
            domain: .UserDomainMask
        )
        let type = chapter.type?.rawValue.lowercaseString
        let managedContext = CoreDataStackManager.sharedManager.managedObjectContext
        let fileDB = File.createFile(file, managedObjectContext: managedContext)
        let chapterDB = Chapter.createChapter(chapter, file: fileDB!)
        chapterDB!.markInDownloadingState()
        let request = Alamofire.download(.GET, "https://\(file.server!)\(file.directory!)/\(chapter.subdirectory!)_\(type!).zip".allowdStringForURL(), destination: destination)
            .response { request, response, _, error in
                let paths =  NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)
                let cacheDir =  paths[0]
                let zipFilePath =  "\(cacheDir)/\(chapter.name!)jp2.zip"
                let unzipSucceed = (SSZipArchive.unzipFileAtPath(zipFilePath, toDestination: "\(self.docuementsDirectory())"))
                if unzipSucceed {
                    self.deleteFile(zipFilePath)
                    self.filesQueue?.indexOf({$0.file?.archiveItem?.identifier == file.archiveItem!.identifier && $0.chapter?.name == chapter.name}).map({
                        if let _ = self.filesQueue![$0].chapter {
                            chapterDB!.markDownloaded(true)
                        }
                        self.filesQueue!.removeAtIndex($0)
                        if self.filesQueue?.count == 0 {self.downloadProgress = 0}
                        self.appDelegate.downloadDone()
                        NSNotificationCenter.defaultCenter().postNotificationName("\(chapter.name!)_finished", object:  nil)
                        NSNotificationCenter.defaultCenter().postNotificationName("download_done", object:  nil)
                    })
                }else {
                    self.deleteFile(zipFilePath)
                    self.filesQueue?.indexOf({$0.file?.archiveItem?.identifier == file.archiveItem!.identifier && $0.chapter?.name == chapter.name}).map({
                        if let _ = self.filesQueue![$0].chapter {
                            chapterDB!.markDownloaded(false)
                        }
                        self.filesQueue!.removeAtIndex($0)
                        if self.filesQueue?.count == 0 {self.downloadProgress = 0}
                        self.appDelegate.downloadFailed()
                        NSNotificationCenter.defaultCenter().postNotificationName("\(chapter.name!)_finished", object:  nil)
                        NSNotificationCenter.defaultCenter().postNotificationName("download_deleted", object:  nil)

                    })
                }
            }
            .progress{ bytesRead, totalBytesRead, totalBytesExpectedToRead in
                self.filesQueue?.indexOf({$0.file?.archiveItem!.identifier == file.archiveItem!.identifier && $0.chapter?.name == chapter.name}).map({
                    self.filesQueue![$0].totalBytesRead = totalBytesRead
                    self.filesQueue![$0].totalBytesExpectedToRead = totalBytesExpectedToRead
                    self.downloadProgress = self.totalProgress!
                    NSNotificationCenter.defaultCenter().postNotificationName("\(chapter.name!)_progress", object:  Double(Float(totalBytesRead)/Float(totalBytesExpectedToRead)))
                    }
                )
        }
        let fileStatus = FileDownloadStatus(file: file, chapter: chapter, totalBytesRead: 0, totalBytesExpectedToRead: 0, request: request)
        filesQueue?.append(fileStatus)
    }
    
    private func deleteChapter(chapter: IAChapter) {
        let type = chapter.type!.rawValue.lowercaseString
        if deleteFile("\(self.docuementsDirectory())/\(chapter.name!)\(type)") {
            let managedContext = CoreDataStackManager.sharedManager.managedObjectContext
            let myfile = File.createFile(chapter.file!, managedObjectContext: managedContext)
            let myChapter = Chapter.createChapter(chapter, file: myfile!)
            myChapter!.markDownloaded(false)
            NSNotificationCenter.defaultCenter().postNotificationName("\(chapter.name!)_deleted", object:  nil)
            NSNotificationCenter.defaultCenter().postNotificationName("download_deleted", object:  nil)
        }else {
        
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
        let chaptersInDownloadState = self.getChaptersInDownloadState()
        for chapter in chaptersInDownloadState as! [Chapter] {
            let myChapter = IAChapter.init(chapter: chapter)
            self.download(myChapter, file: myChapter.file!)
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
    
    func deleteFile(filePath: String) -> Bool {
        do{
            let fileManager = NSFileManager.defaultManager()
            try fileManager.removeItemAtPath(filePath)
        } catch let error as NSError {
            print("delete file failed \(error.localizedDescription)")
            return false
        }
        return true
    }
}