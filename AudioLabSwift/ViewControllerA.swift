//
//  ViewControllerA.swift
//  Created by mingyun zhang on 10/1/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//
import UIKit

class ViewControllerA: UIViewController {

    // MARK: - Properties
    var audioModel: AudioModel! // AudioModel instance to handle audio processing
    
    // MARK: - IBOutlet connections to storyboard UILabels
    @IBOutlet weak var frequencyLabel1: UILabel!  // Label to display the first detected frequency
    @IBOutlet weak var frequencyLabel2: UILabel!  // Label to display the second detected frequency
    @IBOutlet weak var noiseLabel: UILabel!       // Label to display "noise detected" message when no valid frequencies are detected
    @IBOutlet weak var vowelLabel: UILabel!       // Label to display the detected vowel sound
    
    // Threshold and tolerance settings
    private let magnitudeThreshold: Float = -30.0 // dB threshold for displaying frequencies
    private let frequencyTolerance: Float = 3.0   // Frequency tolerance (+-3Hz)
    private let timeInterval: TimeInterval = 0.2  // Time interval for frequency locking (200 milliseconds)
    
    // MARK: - Lifecycle methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize the AudioModel with a buffer size
        audioModel = AudioModel(buffer_size: 1024)
        
        // Start microphone processing at 20 frames per second
        audioModel.startMicrophoneProcessing(withFps: 20.0)
        
        // Set up a timer to call the updateFrequencies() method every 200ms
        Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { [weak self] _ in
            self?.updateFrequencies()
        }
    }
    
    // MARK: - Frequency update logic
    /// Retrieves the two largest frequencies from FFT data and updates the UI
    func updateFrequencies() {
        // Get the two largest frequencies from the FFT data
        if let (freq1, freq2) = audioModel.getMaxToneFromFFT() {
            print("Detected Frequencies: \(freq1) Hz, \(freq2) Hz") // Debugging information
            
            // Update UI to display the detected frequencies
            frequencyLabel1.text = String(format: "%.2f Hz", freq1)
            frequencyLabel2.text = String(format: "%.2f Hz", freq2)
            noiseLabel.text = "" // Clear the noise label when valid frequencies are detected
            
            // Check for vowel sounds ("ooooo" and "ahhhh")
            detectVowel(freq1: freq1, freq2: freq2)
        } else {
            // If no valid frequencies are detected, display noise
            frequencyLabel1.text = "--"
            frequencyLabel2.text = "--"
            vowelLabel.text = ""
            noiseLabel.text = "Noise Detected"
        }
    }
    
    // MARK: - Vowel detection logic
    /// Detects vowel sounds based on frequency ranges
    /// - Parameters:
    ///   - freq1: The first detected frequency
    ///   - freq2: The second detected frequency
    func detectVowel(freq1: Float, freq2: Float) {
        let inRangeForOoooo = (freq1 < 400 && freq2 < 900)
        
        // Update the vowel label based on frequency ranges
        if inRangeForOoooo {
            vowelLabel.text = "ooooo"
            noiseLabel.text = "" // Clear noise label
        } else {
            vowelLabel.text = "ahhhh"
            noiseLabel.text = "" // Clear noise label
        }
    }
    
    // MARK: - Handle audio playback
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Start audio processing when the view appears
        audioModel.play()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Pause audio processing when the view disappears
        audioModel.pause()
    }
}
