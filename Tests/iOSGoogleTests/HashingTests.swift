import XCTest
@testable import iOSGoogle

final class HashingTests: XCTestCase {
    var testURL: URL!
    
    override func setUp() {
        testURL = Bundle.module.bundleURL.appendingPathComponent("ExampleFiles/milky-way-nasa.jpg")
        if testURL == nil {
            XCTFail("Could not get url for example file!")
        }
    }
    
    func testGoogleFromURL() throws {
        let md5Hash = try GoogleHashing().hash(forURL: testURL)
        
        print("md5Hash: \(md5Hash)")
        // I used http://onlinemd5.com to generate the MD5 hash from the image.
        XCTAssert(md5Hash == "F83992DC65261B1BA2E7703A89407E6E".lowercased())
    }
    
    // The purpose of this test is mostly to bootstrap a hash value to use in server tests.
    func testGoogleFromURL2() throws {
        let url = Bundle.module.bundleURL.appendingPathComponent("ExampleFiles/example.url")

        let md5Hash = try GoogleHashing().hash(forURL: url)
        
        print("md5Hash: \(md5Hash)")
        XCTAssert(md5Hash == "958c458be74acfcf327619387a8a82c4")
    }
    
    func testGoogleFromData() throws {
        guard let data = "Hello World".data(using: .utf8) else {
            XCTFail()
            return
        }
        
        let md5Hash = try GoogleHashing().hash(forData: data)
        
        print("md5Hash: \(md5Hash)")
    }
    
    func testGoogleFromData2() throws {
        let data = try Data(contentsOf: testURL)
        
        let md5Hash = try GoogleHashing().hash(forData: data)
        
        print("md5Hash: \(md5Hash)")
    }
}
