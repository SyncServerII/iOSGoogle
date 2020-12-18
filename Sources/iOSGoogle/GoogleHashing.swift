import iOSShared
import Foundation
import ServerShared

// CommonCrypto is only available with Xcode 10 for import into Swift; see also https://stackoverflow.com/questions/25248598/importing-commoncrypto-in-a-swift-framework
import CommonCrypto

public struct GoogleHashing: CloudStorageHashing {
    enum GoogleHashingError: Error {
        case noDataGiven
    }
    
    public var cloudStorageType: CloudStorageType = .Google
    
    public init() {
    }
    
    public func hash(forURL url: URL) throws -> String {
        return try generateMD5(fromURL: url)
    }
    
    public func hash(forData data: Data) throws -> String {
        return try generateMD5(fromData: data)
    }
    
    private static let googleBufferSize = 1024 * 1024

    // I'm having problems with this computing checksums in some cases. Using FileMD5Hash instead.
    // From https://stackoverflow.com/questions/42935148/swift-calculate-md5-checksum-for-large-files
    private func generateMD5(fromURL url: URL) throws -> String {
        do {
            // Open file for reading:
            let file = try FileHandle(forReadingFrom: url)
            defer {
                file.closeFile()
            }

            // Create and initialize MD5 context:
            var context = CC_MD5_CTX()
            CC_MD5_Init(&context)

            // Read up to `bufferSize` bytes, until EOF is reached, and update MD5 context:
            while autoreleasepool(invoking: {
                let data = file.readData(ofLength: Self.googleBufferSize)
                print("data.count: \(data.count)")
                if data.count > 0 {
                    data.withUnsafeBytes {
                        _ = CC_MD5_Update(&context, $0, numericCast(data.count))
                    }
                    return true // Continue
                } else {
                    return false // End of file
                }
            }) { }

            // Compute the MD5 digest:
            var digest = Data(count: Int(CC_MD5_DIGEST_LENGTH))
            digest.withUnsafeMutableBytes {
                _ = CC_MD5_Final($0, &context)
            }

            let hexString = digest.map { String(format: "%02hhx", $0) }.joined()
            return hexString

        } catch {
            logger.error("Cannot open file: \(error.localizedDescription)")
            throw error
        }
    }
    
    func generateMD5(fromData data: Data) throws -> String {
        if data.count == 0 {
            throw GoogleHashingError.noDataGiven
        }

        // Create and initialize MD5 context:
        var context = CC_MD5_CTX()
        CC_MD5_Init(&context)

        data.withUnsafeBytes {
            _ = CC_MD5_Update(&context, $0, numericCast(data.count))
        }

        // Compute the MD5 digest:
        var digest = Data(count: Int(CC_MD5_DIGEST_LENGTH))
        digest.withUnsafeMutableBytes {
            _ = CC_MD5_Final($0, &context)
        }

        let hexString = digest.map { String(format: "%02hhx", $0) }.joined()
        return hexString
    }
}
