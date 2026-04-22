@preconcurrency import AVFoundation
import CoreImage
import QuartzCore
import SwiftUI

final class DetectionCameraController: NSObject {
    let session = AVCaptureSession()
    var onFrameJPEG: ((Data, CGSize) -> Void)?

    private let output = AVCaptureVideoDataOutput()
    private let outputQueue = DispatchQueue(label: "baby.camera.output")
    private let ciContext = CIContext()
    private var isConfigured = false
    private var lastEmissionTime = CACurrentMediaTime()
    private let minimumFrameInterval: Double = 0.2

    func start() throws {
        if !isConfigured {
            try configureSession()
        }

        if !session.isRunning {
            outputQueue.async { [session] in
                session.startRunning()
            }
        }
    }

    func stop() {
        if session.isRunning {
            outputQueue.async { [session] in
                session.stopRunning()
            }
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        session.sessionPreset = .high

        defer {
            session.commitConfiguration()
            isConfigured = true
        }

        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        guard let device = AVCaptureDevice.default(for: .video) else {
            throw NSError(domain: "DetectionCameraController", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "没有找到可用摄像头。"
            ])
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw NSError(domain: "DetectionCameraController", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "无法添加摄像头输入。"
            ])
        }
        session.addInput(input)

        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: outputQueue)
        guard session.canAddOutput(output) else {
            throw NSError(domain: "DetectionCameraController", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "无法添加摄像头输出。"
            ])
        }
        session.addOutput(output)

        let connection = output.connection(with: .video)
        connection?.automaticallyAdjustsVideoMirroring = false
        connection?.isVideoMirrored = true
    }
}

extension DetectionCameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        guard now - lastEmissionTime >= minimumFrameInterval else { return }
        lastEmissionTime = now

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let jpegData = ciContext.jpegRepresentation(of: ciImage, colorSpace: colorSpace) else { return }

        let frameSize = CGSize(
            width: CVPixelBufferGetWidth(imageBuffer),
            height: CVPixelBufferGetHeight(imageBuffer)
        )
        onFrameJPEG?(jpegData, frameSize)
    }
}

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        view.previewLayer.connection?.automaticallyAdjustsVideoMirroring = false
        view.previewLayer.connection?.isVideoMirrored = true
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        nsView.previewLayer.session = session
        nsView.previewLayer.connection?.automaticallyAdjustsVideoMirroring = false
        nsView.previewLayer.connection?.isVideoMirrored = true
    }
}

final class CameraPreviewNSView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = previewLayer
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }
}

struct DetectionOverlayView: View {
    let detections: [DetectionBox]
    let frameSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            if frameSize.width > 0, frameSize.height > 0 {
                let contentRect = aspectFillRect(containerSize: geometry.size, imageSize: frameSize)
                ForEach(detections) { detection in
                    if detection.box.count >= 4 {
                        let rect = projectedRect(for: detection.box, in: contentRect)
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.green, lineWidth: 2)
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                            .overlay(alignment: .topLeading) {
                                Text("\(detection.label) \(String(format: "%.2f", detection.confidence))")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.72), in: Capsule())
                                    .foregroundStyle(.white)
                                    .offset(x: rect.minX, y: rect.minY - 12)
                            }
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func aspectFillRect(containerSize: CGSize, imageSize: CGSize) -> CGRect {
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / max(containerSize.height, 1)

        if imageAspect > containerAspect {
            let height = containerSize.height
            let width = height * imageAspect
            return CGRect(x: (containerSize.width - width) / 2, y: 0, width: width, height: height)
        } else {
            let width = containerSize.width
            let height = width / imageAspect
            return CGRect(x: 0, y: (containerSize.height - height) / 2, width: width, height: height)
        }
    }

    private func projectedRect(for box: [Double], in rect: CGRect) -> CGRect {
        let scaleX = rect.width / frameSize.width
        let scaleY = rect.height / frameSize.height
        return CGRect(
            x: rect.minX + (box[0] * scaleX),
            y: rect.minY + (box[1] * scaleY),
            width: (box[2] - box[0]) * scaleX,
            height: (box[3] - box[1]) * scaleY
        )
    }
}
