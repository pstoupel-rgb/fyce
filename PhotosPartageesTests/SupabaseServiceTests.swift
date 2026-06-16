import XCTest
@testable import PhotosPartagees

/// Intercepte les requêtes réseau pour tester `SupabaseService` sans serveur.
final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = StubURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class SupabaseServiceTests: XCTestCase {

    private let configured = SupabaseConfiguration(
        url: URL(string: "https://test.supabase.co")!,
        anonKey: "test-key",
        bucket: "bucket"
    )

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testUploadReturnsObjectPath() async throws {
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let service = SupabaseService(configuration: configured, session: makeSession())

        let path = try await service.upload(data: Data([0x1, 0x2]), fileName: "abc.jpg", contentType: "image/jpeg")
        XCTAssertEqual(path, "bucket/abc.jpg")
    }

    func testUploadFailsOnServerError() async {
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data("boom".utf8))
        }
        let service = SupabaseService(configuration: configured, session: makeSession())

        do {
            _ = try await service.upload(data: Data(), fileName: "x.jpg", contentType: "image/jpeg")
            XCTFail("L'upload aurait dû échouer")
        } catch {
            // attendu
        }
    }

    func testUploadThrowsWhenNotConfigured() async {
        let notConfigured = SupabaseConfiguration(
            url: URL(string: "https://YOUR-PROJECT-REF.supabase.co")!,
            anonKey: "YOUR-ANON-KEY",
            bucket: "bucket"
        )
        let service = SupabaseService(configuration: notConfigured, session: makeSession())

        do {
            _ = try await service.upload(data: Data(), fileName: "x.jpg", contentType: "image/jpeg")
            XCTFail("Devrait lever notConfigured")
        } catch {
            // attendu
        }
    }

    func testCreateSignedURL() async throws {
        StubURLProtocol.handler = { request in
            let json = Data(#"{"signedURL":"/object/sign/bucket/abc.jpg?token=xyz"}"#.utf8)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }
        let service = SupabaseService(configuration: configured, session: makeSession())

        let url = try await service.createSignedURL(path: "bucket/abc.jpg", expiresIn: 60)
        XCTAssertTrue(url.absoluteString.contains("/storage/v1/object/sign/bucket/abc.jpg"))
        XCTAssertTrue(url.absoluteString.contains("token=xyz"))
    }

    func testFileMetadataDefaultsToJPEG() {
        let meta = SupabaseService.fileMetadata(forUTI: nil, assetID: "ABC/123")
        XCTAssertEqual(meta.fileName, "ABC_123.jpg")
        XCTAssertEqual(meta.contentType, "image/jpeg")
    }
}
