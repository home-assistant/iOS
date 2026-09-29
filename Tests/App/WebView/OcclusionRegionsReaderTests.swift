import Foundation
@testable import HomeAssistant
import SwiftUI
import Testing
import UIKit

@MainActor
struct OcclusionRegionsReaderTests {
    private let bounds = CGRect(x: 0, y: 0, width: 678, height: 80)

    @Test("A cutout reaching in from the trailing side pushes content off that side only")
    func trailingCutout() {
        let camera = CGRect(x: 595, y: 20, width: 83, height: 83)
        let insets = OcclusionRegionsReader.ReaderView.horizontalInsets(avoiding: [camera], in: bounds)
        #expect(insets.trailing == 83)
        #expect(insets.leading == 0)
    }

    @Test("A cutout on the leading side pushes content off the leading side")
    func leadingCutout() {
        let camera = CGRect(x: -10, y: 0, width: 50, height: 50)
        let insets = OcclusionRegionsReader.ReaderView.horizontalInsets(avoiding: [camera], in: bounds)
        #expect(insets.leading == 40)
        #expect(insets.trailing == 0)
    }

    @Test("Cutouts outside the view, and the largest of several, are handled")
    func nonIntersectingAndMultiple() {
        let above = CGRect(x: 595, y: -200, width: 83, height: 83)
        #expect(OcclusionRegionsReader.ReaderView.horizontalInsets(avoiding: [above], in: bounds) == EdgeInsets())

        let small = CGRect(x: 640, y: 0, width: 38, height: 38)
        let large = CGRect(x: 595, y: 0, width: 83, height: 83)
        let insets = OcclusionRegionsReader.ReaderView.horizontalInsets(avoiding: [small, large], in: bounds)
        #expect(insets.trailing == 83)
    }

    @Test("The reader stays out of the way and reports once, with nothing to avoid on a flat screen")
    func readerReports() {
        let view = OcclusionRegionsReader.ReaderView(frame: bounds)
        var reported: [EdgeInsets] = []
        view.onChange = { reported.append($0) }
        #expect(!view.isUserInteractionEnabled)

        view.layoutSubviews()
        view.layoutSubviews()
        #expect(reported == [EdgeInsets()])
    }
}
