//
//  ViewControllerB.swift
//  Created by mingyun zhang on 10/1/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//

import UIKit

class ViewControllerB: UIViewController {

    // MARK: - IBOutlet connections for UI elements
    @IBOutlet weak var userView: UIView!          // View to display the graphical FFT output
    @IBOutlet weak var motionLabel: UILabel!      // Label to display detected motion (towards or away)
    @IBOutlet weak var frequencyLabel: UILabel!   // Label to display the current frequency

    // MARK: - Audio Constants
    struct AudioConstants {
        static let AUDIO_BUFFER_SIZE = 4096 * 4   // Buffer size for audio processing
    }

    // MARK: - Properties
    // Audio model for microphone processing and frequency handling
    let audiomodelb = AudioModelB(bufferSize: AudioConstants.AUDIO_BUFFER_SIZE, sineFrequency: 17500)

    // Lazy initialization of a MetalGraph object to visualize the FFT data
    lazy var graph: MetalGraph? = MetalGraph(userView: self.userView)

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set background color for the graph (black in this case)
        graph?.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
        
        // Add an FFT graph to visualize the data, normalizing it for FFT and setting the number of points
        graph?.addGraph(withName: "fft", shouldNormalizeForFFT: true, numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE / 2)
        
        // Configure grids for better visualization of the graph
        graph?.makeGrids()

        // Start microphone processing with 20 frames per second
        audiomodelb.startMicrophoneProcessing(withFps: 20)
        
        // Start audio playback
        audiomodelb.play()

        // Schedule the update function to run every 0.05 seconds to refresh the graph and UI
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.update()
        }
    }

    // MARK: - Frequency Slider Action
    // Adjust frequency based on the slider value
    @IBAction func frequencySlider(_ sender: UISlider) {
        // Set the frequency for the AudioModelB
        audiomodelb.setFrequency(frequency: sender.value)
        
        // Update the frequency label to display the new frequency in Hz
        frequencyLabel.text = String(format: "%.0f Hz", sender.value)
    }

    // MARK: - Update Methods
    // General update method called periodically to update the graph and motion label
    func update() {
        updateGraph()   // Update the FFT graph
        updateMovement() // Update motion detection status
        // Update the frequency label with the current sine frequency
        frequencyLabel.text = String(format: "%.0f Hz", audiomodelb.sineFrequency)
    }
    
    // Update the graph with the latest FFT data
    func updateGraph() {
        // Pass the FFT data from AudioModelB to the graph for visualization
        graph?.updateGraph(data: audiomodelb.fftData, forKey: "fft")
    }

    // Update the motion label based on detected movement
    func updateMovement() {
        // Retrieve left and right movement detection from AudioModelB
        let left = audiomodelb.getLeftMovement()
        let right = audiomodelb.getRightMovement()

        // Update the motion label based on movement direction
        if right {
            self.motionLabel.text = "Moving Away"
        } else if left {
            self.motionLabel.text = "Moving Towards"
        } else {
            self.motionLabel.text = "No Movement"
        }
    }
}
