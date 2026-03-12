// CameraPreviewView.swift
// 养生八段锦 iPad App - 摄像头预览层（UIViewRepresentable 包装）

import SwiftUI
import AVFoundation

/// 摄像头实时预览层
struct CameraPreviewView: UIViewRepresentable {
    let cameraService: CameraService

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.setupPreviewLayer(for: cameraService.captureSession)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

/// 包装 AVCaptureVideoPreviewLayer 的 UIView
class CameraPreviewUIView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    func setupPreviewLayer(for session: AVCaptureSession) {
        guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else { return }
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill  // 填满整个预览区域
        previewLayer.connection?.isVideoMirrored = true  // 前置摄像头镜像
        self.previewLayer = previewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}
