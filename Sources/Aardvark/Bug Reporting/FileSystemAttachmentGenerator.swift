//
//  Copyright 2021 Square, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

@objc(ARKFileSystemAttachmentGenerator)
public final class FileSystemAttachmentGenerator: NSObject {

    // MARK: - Public Static Methods

    /// Generates bug report attachments representing the data in the log store.
    ///
    /// This is a convenience for asynchronously retrieving the messages from the log store and generating the
    /// appropriate attachments from those messages.
    ///
    /// - parameter logStore: The log store from which to read the messages.
    /// - parameter messageFormatter: The formatter used to format messages in the logs attachment.
    /// - parameter includeLatestScreenshot: Whether an attachment should be generated for the last screenshot in the
    /// log store, if one exists.
    /// - parameter completionQueue: The queue on which the completion should be called.
    /// - parameter completion: The completion to be called once the attachments have been generated.
    public static func attachment() throws -> ARKBugReportAttachment {
        let fileManager = FileManager.default

        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)

        let propertyKeys: [URLResourceKey] = [
            .fileSizeKey,
            .creationDateKey,
            .contentModificationDateKey,
            .isDirectoryKey,
        ]

        let fileSizeFormatter = ByteCountFormatter()
        fileSizeFormatter.zeroPadsFractionDigits = true

        var description = ""

        for directoryURL in urls {
            guard let enumerator = fileManager.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: propertyKeys
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(propertyKeys))

                guard
                    // let isDirectory = resourceValues.isDirectory,
                    let fileSize = resourceValues.fileSize
                else {
                    continue
                }

                let formattedFileSize = fileSizeFormatter.string(fromByteCount: Int64(fileSize))
                description += "\(formattedFileSize) \(fileURL.path)\n"
            }
        }

        if let volumeURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let keys: Set<URLResourceKey> = [
                .volumeAvailableCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityForOpportunisticUsageKey,
                .volumeTotalCapacityKey,
            ]

            let resourceValues = try volumeURL.resourceValues(forKeys: keys)

            guard
                let availableCapacity = resourceValues.volumeAvailableCapacity,
                let importantAvailableCapacity = resourceValues.volumeAvailableCapacityForImportantUsage,
                let opportunisticAvailableCapacity = resourceValues.volumeAvailableCapacityForOpportunisticUsage,
                let totalCapacity = resourceValues.volumeTotalCapacity
            else {
                fatalError()
            }

            description += """

                Available Capacity:         \(fileSizeFormatter.string(fromByteCount: Int64(availableCapacity)))
                  for Important Usage:      \(fileSizeFormatter.string(fromByteCount: Int64(importantAvailableCapacity)))
                  for Opportunistic Usage:  \(fileSizeFormatter.string(fromByteCount: Int64(opportunisticAvailableCapacity)))
                Total Capacity:             \(fileSizeFormatter.string(fromByteCount: Int64(totalCapacity)))
                """
        }

        return ARKBugReportAttachment(
            fileName: "file_system.txt",
            data: Data(description.utf8),
            dataMIMEType: "text/plain"
        )
    }

}
