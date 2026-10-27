//
//  FaceAlignmentConfiguration.swift
//  FaceRecognitionR300
//
//  Created by Jakub Dolejs on 03/02/2026.
//

import Foundation

public struct FaceAlignmentConfiguration {
    public var scale: Double = 2.85
    /// Vertical offset applied during alignment.
    ///
    /// 0.35 matches every non-Apple implementation: Android's `FaceAligner.yofs`, the .NET
    /// `FaceAligner` used by `ArcIdv.ModelService` and `EdgeFaceRecognitionService`, the browser,
    /// and `FaceCaptureApp` and `PassportVerifyApp`. Apple alone used 0.4, which is a defect
    /// rather than a configuration choice.
    public var verticalOffset: Double = 0.35
    internal init() {}
}
