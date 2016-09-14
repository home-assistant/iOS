//
//  NotificationService.swift
//  APNSAttachmentService
//
//  Created by Robbie Trencheny on 9/8/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void){
        print("APNSAttachmentService started!")
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        func failEarly() {
            contentHandler(request.content)
        }
        
        guard let content = (request.content.mutableCopy() as? UNMutableNotificationContent) else {
            return failEarly()
        }
        
        guard let attachmentString = content.userInfo["attachment-url"] as? String else {
            return failEarly()
        }
        
        guard let attachmentURL = URL(string: attachmentString) else {
            return failEarly()
        }
        
        guard let attachmentData = NSData(contentsOf:attachmentURL) else { return failEarly() }
        guard let attachment = UNNotificationAttachment.create(fileIdentifier: attachmentURL.lastPathComponent, data: attachmentData, options: nil) else { return failEarly() }
        content.attachments.append(attachment)
        
        contentHandler(content.copy() as! UNNotificationContent)
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
    
}

extension UNNotificationAttachment {
    
    /// Save the attachment URL to disk
    static func create(fileIdentifier: String, data: NSData, options: [NSObject : AnyObject]?) -> UNNotificationAttachment? {
        let fileManager = FileManager.default
        let tmpSubFolderName = ProcessInfo.processInfo.globallyUniqueString
        let tmpSubFolderURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(tmpSubFolderName, isDirectory: true)
        
        do {
            try fileManager.createDirectory(at: tmpSubFolderURL!, withIntermediateDirectories: true, attributes: nil)
            let fileURL = tmpSubFolderURL?.appendingPathComponent(fileIdentifier)
            try data.write(to: fileURL!, options: [])
            return try UNNotificationAttachment.init(identifier: "", url: fileURL!, options: options)
        } catch let error {
            print("error \(error)")
        }
        
        return nil
    }
}
