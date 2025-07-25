import XCTest
@testable import Ashton

#if os(macOS)
import AppKit
#elseif os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#endif

final class AshtonConcurrencyTests: XCTestCase {

    func testConcurrentDecodingIsThreadSafe() {
        // A collection of different HTML strings to parse, to vary the work being done
        let htmlSamples = [
            "<p>Hello <b>World</b></p>",
            "<em>This is a test</em> with <i>multiple</i> tags.",
            "<font color=\"#ff0000\">Red text</font>",
            "A string with no tags at all.",
            "<p>Nested <b>bold <i>and italic</i></b> text</p>",
            "<p style=\"color: blue; font-size: 14px;\">Styled paragraph</p>",
            "<strong>Strong text</strong> and <em>emphasized text</em>",
            "<p>Multiple<br/>lines<br/>of<br/>text</p>"
        ]
        
        // Pre-calculate the expected plain text for each sample
        let expectedOutputs = htmlSamples.map { html in
            return (html: html, plainText: Ashton.decode(html).string)
        }

        // Use a high iteration count to increase the chance of triggering a race
        let iterationCount = 1000
        let expectation = self.expectation(description: "Concurrent decoding completes without crashing or data races.")
        expectation.expectedFulfillmentCount = iterationCount

        // Use concurrentPerform to run the block on multiple threads simultaneously
        DispatchQueue.global().async {
            DispatchQueue.concurrentPerform(iterations: iterationCount) { i in
                // Pick a sample to ensure threads are doing slightly different work
                let sample = expectedOutputs[i % expectedOutputs.count]
                
                // The core operation we are stress-testing
                let result = Ashton.decode(sample.html)
                
                // Verify we got a valid result with correct content
                XCTAssertNotNil(result)
                XCTAssertEqual(result.string, sample.plainText, "Decoded content mismatch under concurrent load for HTML: \(sample.html)")
                
                expectation.fulfill()
            }
        }

        // Wait for all concurrent operations to complete
        // A long timeout is fine here; the goal is to find crashes/races, not to be fast
        waitForExpectations(timeout: 30.0)
    }
    
    func testConcurrentEncodingIsThreadSafe() {
        // Create various attributed strings to encode
        var attributedStrings: [NSAttributedString] = [
            NSAttributedString(string: "Simple text")
        ]
        
        #if os(macOS)
        attributedStrings.append(NSAttributedString(string: "Bold text", attributes: [.font: NSFont.boldSystemFont(ofSize: 14)]))
        if let italicFont = NSFontManager.shared.font(withFamily: NSFont.systemFont(ofSize: 14).familyName ?? "Helvetica", 
                                                       traits: .italicFontMask, 
                                                       weight: 5, 
                                                       size: 14) {
            attributedStrings.append(NSAttributedString(string: "Italic text", attributes: [.font: italicFont]))
        }
        attributedStrings.append(NSAttributedString(string: "Colored text", attributes: [.foregroundColor: NSColor.red]))
        #elseif os(iOS) || os(tvOS) || os(watchOS)
        attributedStrings.append(NSAttributedString(string: "Bold text", attributes: [.font: UIFont.boldSystemFont(ofSize: 14)]))
        attributedStrings.append(NSAttributedString(string: "Italic text", attributes: [.font: UIFont.italicSystemFont(ofSize: 14)]))
        attributedStrings.append(NSAttributedString(string: "Colored text", attributes: [.foregroundColor: UIColor.red]))
        #endif
        
        let iterationCount = 1000
        let expectation = self.expectation(description: "Concurrent encoding completes without crashing or data races.")
        expectation.expectedFulfillmentCount = iterationCount
        
        DispatchQueue.global().async {
            DispatchQueue.concurrentPerform(iterations: iterationCount) { i in
                // Pick a sample to ensure threads are doing slightly different work
                let attributedString = attributedStrings[i % attributedStrings.count]
                
                // The core operation we are stress-testing
                let html = Ashton.encode(attributedString)
                
                // Verify we got a valid result
                XCTAssertNotNil(html)
                XCTAssertFalse(html.isEmpty)
                
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 30.0)
    }
    
    func testConcurrentMixedOperationsAreThreadSafe() {
        // Test both encoding and decoding happening simultaneously
        let htmlSamples = [
            "<p>Test <b>HTML</b></p>",
            "<em>Another test</em>"
        ]
        
        var attributedStrings = [
            NSAttributedString(string: "Test string")
        ]
        
        #if os(macOS)
        attributedStrings.append(NSAttributedString(string: "Another string", attributes: [.font: NSFont.boldSystemFont(ofSize: 14)]))
        #elseif os(iOS) || os(tvOS) || os(watchOS)
        attributedStrings.append(NSAttributedString(string: "Another string", attributes: [.font: UIFont.boldSystemFont(ofSize: 14)]))
        #endif
        
        let iterationCount = 1000
        let expectation = self.expectation(description: "Mixed concurrent operations complete without crashing.")
        expectation.expectedFulfillmentCount = iterationCount
        
        DispatchQueue.global().async {
            DispatchQueue.concurrentPerform(iterations: iterationCount) { i in
                if i % 2 == 0 {
                    // Decode on even iterations
                    let html = htmlSamples[i % htmlSamples.count]
                    _ = Ashton.decode(html)
                } else {
                    // Encode on odd iterations
                    let attributedString = attributedStrings[i % attributedStrings.count]
                    _ = Ashton.encode(attributedString)
                }
                
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 30.0)
    }
    
    func testCacheClearingDuringConcurrentOperations() {
        // Test that clearing caches while operations are in progress doesn't cause issues
        let html = "<p>Cache test <b>content</b></p>"
        let iterationCount = 100
        
        let decodeExpectation = self.expectation(description: "Decoding operations complete")
        decodeExpectation.expectedFulfillmentCount = iterationCount
        
        let clearExpectation = self.expectation(description: "Cache clearing operations complete")
        clearExpectation.expectedFulfillmentCount = 10
        
        // Start many decode operations
        DispatchQueue.global().async {
            DispatchQueue.concurrentPerform(iterations: iterationCount) { _ in
                let result = Ashton.decode(html)
                XCTAssertNotNil(result, "Decoding should not fail during concurrent cache clearing")
                XCTAssertFalse(result.string.isEmpty, "Decoded result should not be empty during cache clearing")
                decodeExpectation.fulfill()
            }
        }
        
        // Simultaneously clear caches periodically
        DispatchQueue.global().async {
            for _ in 0..<10 {
                Thread.sleep(forTimeInterval: 0.01) // Small delay between clears
                Ashton.clearCaches()
                clearExpectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 30.0)
    }
    
    func testHighContentionCacheAccessIsThreadSafe() {
        // Single HTML that every thread will request to stress the cache lock
        let highlyContendedHtml = "<p>This is a <b>single</b> string that <i>every</i> thread will request to stress the cache lock.</p>"
        let iterationCount = 1000
        let expectation = self.expectation(description: "Concurrent decoding of the same input completes correctly.")
        expectation.expectedFulfillmentCount = iterationCount
        
        // Pre-calculate the single expected result
        let expectedPlainText = Ashton.decode(highlyContendedHtml).string
        
        DispatchQueue.global().async {
            DispatchQueue.concurrentPerform(iterations: iterationCount) { _ in
                let result = Ashton.decode(highlyContendedHtml)
                XCTAssertNotNil(result)
                XCTAssertEqual(result.string, expectedPlainText, "High contention on a single resource should not lead to corruption.")
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10.0)
    }
    
    func testConcurrentEdgeCases() {
        // Edge cases including empty, malformed, and unusual HTML
        let edgeCaseSamples = [
            "", // Empty string
            "<>", // Malformed HTML
            "<p></p>", // Empty tags
            "<<<<>>>>", // Multiple malformed brackets
            "&lt;&gt;&amp;", // HTML entities only
            String(repeating: "<p>Large content</p>", count: 100) // Large HTML
        ]
        
        let iterationCount = 1000
        let expectation = self.expectation(description: "Concurrent edge case handling completes without crashing.")
        expectation.expectedFulfillmentCount = iterationCount
        
        DispatchQueue.global().async {
            DispatchQueue.concurrentPerform(iterations: iterationCount) { i in
                let html = edgeCaseSamples[i % edgeCaseSamples.count]
                // For edge cases, we mainly care about stability
                let result = Ashton.decode(html)
                // Should not crash, but may return nil or empty for malformed input
                _ = result // Just ensure it doesn't crash
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10.0)
    }
}