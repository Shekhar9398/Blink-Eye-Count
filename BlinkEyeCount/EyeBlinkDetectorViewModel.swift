import AVFoundation
import Vision
import Combine

class EyeBlinkDetectorViewModel: NSObject, ObservableObject {
    @Published var blinkCount = 0
    
    let captureSession = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let faceDetectionRequest = VNDetectFaceLandmarksRequest()
    
    private var isBlinking = false
    private var baselineEyeHeight: CGFloat = 0.1
    private var eyeHeightHistory: [CGFloat] = []
    
    override init() {
        super.init()
        setupCamera()
    }
    
    // MARK: - Camera Setup
    func setupCamera() {
        captureSession.sessionPreset = .high
        
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    self.configureSession()
                } else {
                    print("Camera access denied.")
                }
            }
        }
    }
    
    private func configureSession() {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            print("Error: Cannot access camera.")
            return
        }
        
        captureSession.beginConfiguration()
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoDataOutputQueue"))
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
        
        captureSession.commitConfiguration()
    }
    
    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }

    
    func stopSession() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    // MARK: - Blink Detection
    private func detectBlinks(from sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored, options: [:])
        do {
            try handler.perform([faceDetectionRequest])
            if let results = faceDetectionRequest.results as? [VNFaceObservation] {
                print("Number of faces detected: \(results.count)")
                for face in results {
                    if let landmarks = face.landmarks, let leftEye = landmarks.leftEye, let rightEye = landmarks.rightEye {
                        let leftEyeHeight = smoothEyeHeight(eyeHeight(from: leftEye))
                        let rightEyeHeight = smoothEyeHeight(eyeHeight(from: rightEye))

                        print("Left Eye Height: \(leftEyeHeight), Right Eye Height: \(rightEyeHeight)")

                        if baselineEyeHeight == 0.1, leftEyeHeight > 0.02, rightEyeHeight > 0.02 {
                            baselineEyeHeight = (leftEyeHeight + rightEyeHeight) / 2
                            print("Calibrated baseline eye height: \(baselineEyeHeight)")
                        }

                        let isCurrentlyBlinking = leftEyeHeight < baselineEyeHeight * 0.6 || rightEyeHeight < baselineEyeHeight * 0.6

                        if isCurrentlyBlinking && !isBlinking {
                            DispatchQueue.main.async {
                                self.blinkCount += 1
                                print("Blink count updated: \(self.blinkCount)")
                            }
                            isBlinking = true
                        } else if !isCurrentlyBlinking {
                            isBlinking = false
                        }
                    } else {
                        print("Face detected but no eye landmarks found.")
                    }
                }
            } else {
                print("No face detected.")
            }
        } catch {
            print("Error performing face detection: \(error)")
        }
    }

    
    private func eyeHeight(from eye: VNFaceLandmarkRegion2D) -> CGFloat {
        guard eye.pointCount > 1 else { return 0 }
        let points = eye.normalizedPoints
        let minY = points.map { $0.y }.min() ?? 0
        let maxY = points.map { $0.y }.max() ?? 0
        return maxY - minY
    }
    
    private func smoothEyeHeight(_ newHeight: CGFloat) -> CGFloat {
        eyeHeightHistory.append(newHeight)
        if eyeHeightHistory.count > 5 {
            eyeHeightHistory.removeFirst()
        }
        return eyeHeightHistory.reduce(0, +) / CGFloat(eyeHeightHistory.count)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension EyeBlinkDetectorViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        detectBlinks(from: sampleBuffer)
    }
}
