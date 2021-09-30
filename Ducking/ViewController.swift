//
//  ViewController.swift
//  Ducking
//
//  Created by Tyler Hall on 9/29/21.
//

import UIKit
import ARKit
import Vision

class ViewController: UIViewController {

    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var duckView: DuckView!

    let config = ARWorldTrackingConfiguration()
    var coachingOverlay = ARCoachingOverlayView()

    var isRecognizing = false

    var missingCount = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.session.run(config, options: [])
        sceneView.session.delegate = self
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
    }
}

extension ViewController: ARSessionDelegate {

}

extension ViewController: ARSCNViewDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {

        func nope() {
            isRecognizing = false
        }

        guard !isRecognizing else { return }
        isRecognizing = true

        guard let cvPixelBuffer = sceneView.session.currentFrame?.capturedImage else { nope(); return }

        let width = self.sceneView.bounds.size.width
        let height = self.sceneView.bounds.size.height

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }

            var info = CMSampleTimingInfo()
            info.presentationTimeStamp = CMTime.zero
            info.duration = CMTime.invalid
            info.decodeTimeStamp = CMTime.invalid

            var formatDesc: CMFormatDescription? = nil
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: cvPixelBuffer, formatDescriptionOut: &formatDesc)
            var sampleBuffer: CMSampleBuffer? = nil

            CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: cvPixelBuffer, formatDescription: formatDesc!, sampleTiming: &info, sampleBufferOut: &sampleBuffer)

            guard let sampleBuffer = sampleBuffer else { nope(); return }

            let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .right, options: [:])

            let handPoseRequest = VNDetectHumanHandPoseRequest()
            handPoseRequest.maximumHandCount = 2

            try? handler.perform([handPoseRequest])

            var points = [CGPoint]()
            for observation in (handPoseRequest.results ?? []) {
                guard let middlePoints = try? observation.recognizedPoints(.middleFinger) else { continue }
                guard let indexPoints = try? observation.recognizedPoints(.indexFinger) else { continue }

                guard let middleTipY = middlePoints[.middleTip]?.location.y else { continue }
                guard let middlePipY = middlePoints[.middlePIP]?.location.y else { continue }

                guard let indexTipY = indexPoints[.indexTip]?.location.y else { continue }
                guard let indexPipY = indexPoints[.indexPIP]?.location.y else { continue }

                let a = (middlePipY < middleTipY)
                let b = (indexPipY < indexTipY)

                guard a != b else { continue }

                guard let middleTipX = middlePoints[.middleTip]?.location.x else { continue }

                let vx = CGFloat(width) * middleTipX
                let vy = CGFloat(height) * (1 - middleTipY)

                points.append(CGPoint(x: vx, y: vy))
            }

            DispatchQueue.main.async { [weak self] in
                self?.duckView.setDuck1(point: points[safe: 0])
                self?.duckView.setDuck2(point: points[safe: 1])
                self?.isRecognizing = false
            }
        }
    }
}

class DuckView: UIView {

    let size: CGFloat = 200

    let duck1 = UIImageView(image: UIImage(named: "Duck"))
    let duck2 = UIImageView(image: UIImage(named: "Duck"))

    var duck1Timer: Timer?
    var duck2Timer: Timer?

    var player: AVAudioPlayer?

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear

        duck1.isHidden = true
        duck2.isHidden = true

        addSubview(duck1)
        addSubview(duck2)

        player = try? AVAudioPlayer(contentsOf: Bundle.main.url(forResource: "quack", withExtension: "mp3")!)
        player?.prepareToPlay()
    }

    func setDuck1(point: CGPoint?) {
        if let point = point {
            duck1Timer?.invalidate()
            duck1Timer = nil

            duck1.frame = CGRect(x: point.x - (size / 2), y: point.y - (size / 2), width: size, height: size)

            if duck1.isHidden {
                player?.play()
            }

            duck1.isHidden = false
        } else {
            if duck1Timer == nil {
                duck1Timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false, block: { [weak self] _ in
                    self?.duck1.isHidden = true
                })
            }
        }
    }

    func setDuck2(point: CGPoint?) {
        if let point = point {
            duck2Timer?.invalidate()
            duck2Timer = nil

            duck2.frame = CGRect(x: point.x - (size / 2), y: point.y - (size / 2), width: size, height: size)

            if duck2.isHidden {
                player?.play()
            }

            duck2.isHidden = false
        } else {
            if duck2Timer == nil {
                duck2Timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false, block: { [weak self] _ in
                    self?.duck2.isHidden = true
                })
            }
        }
    }
}

extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
