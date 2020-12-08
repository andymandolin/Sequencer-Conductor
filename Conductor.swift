//
//  Conductor.swift
//  Sequencer
//
//  Created by Q LIVE, LLC on 9/22/19.
//  Copyright © 2019 Q LIVE, LLC. All rights reserved.
//

import Foundation
import AudioKit

class Conductor {

    //Create singleton to maintain audio functionality
    static let sharedInstance = Conductor()

    //Mixer nodes
    var mixer: AKMixer
    var submixClicks: AKMixer
    var submixCues: AKMixer
    var submixPads: AKMixer
    
    //Playback for audio samples and pad track
    let clicksCuesSequencer: ClicksCuesSequencer
    var padPlayer : AKPlayer
    
    let settings = AKSettings()

    //Initial settings
    var padsArePanned = true //Required as padPlayers need a reference to set pan upon creation
    var shouldLoop = true
    var shouldCountIn = true

    var playerArray : [AKPlayer]//All pads players go here so they can be controlled/stopped as a group

    init() {

        clicksCuesSequencer = ClicksCuesSequencer()
        padPlayer = AKPlayer()
        
        playerArray = [AKPlayer]()

        //Create instances of all mixers
        mixer = AKMixer()
        submixClicks = AKMixer()
        submixCues = AKMixer()
        submixPads = AKMixer()

        //Setup callbacks and tracks
        clicksCuesSequencer.addCallbackTrackToSequencer()
        clicksCuesSequencer.setupCallbackWithSong()

        //Initial routing, order is important
        performAllRouting()
        routeAudioKitToMixer()

        clicksCuesSequencer.clicks.clicksFocusedVolume(whichClicks: 0)

        //AudioKit must be started after all setup and routing has been performed
        startAudioKit()
        
        print("Conductor init")
    }
    
    func recreatePadPlayer() {
        var playerArray = [AKPlayer]()
        var padPlayer = AKPlayer()
    }
    
    func checkAKStatus() -> Bool {
        return AudioKit.engine.isRunning
    }
    
    func recreateMixers() {
        mixer = AKMixer()
        submixClicks = AKMixer()
        submixCues = AKMixer()
        submixPads = AKMixer()
    }

    // MARK: - AudioKit
    func startAudioKit() {
        do {
            try AudioKit.start()
            AKLog("setup Conductor Init: AudioKit started")
        } catch let err {
            AKLog("Conductor Init: AudioKit failed to start for reason: \(err)")
        }
    }

    func stopAudioKit() {
        do {
            try AudioKit.stop()
                AKLog("setup Conductor Init: AudioKit stoped")
            } catch let err {
                AKLog("Conductor Init: AudioKit failed to stop for reason: \(err)")
            }
    }

    func deconstruct() {
        clicksCuesSequencer.clearSequencerIncludingCallbackTracks()
    }
    
    // MARK: - Pad playback methods
    var timer = Timer()
    
    @objc func timerAction(sender: Timer){
        self.padPlayer.fadeOutAndStop(time: 6) //Fade out and stop playback of any previous pad players
        self.createPlayerWithLoadingAndPlay(padButtonName: sender.userInfo as! String) //Create new pad player instance
    }
    
    func padsLoopingPlayback(senderPadButtonName: String) {
        timer.invalidate()

        guard shouldLoop else { return }//If no pad has been selected
        if senderPadButtonName == "" {
            timer.invalidate()
            for player in playerArray {
                       player.fadeOutAndStop(time: 6)
                   }
            return
        }
        //...Otherwise create array of pads
        for player in playerArray {
            timer.invalidate()
            player.fadeOutAndStop(time: 6)
            print("here fading out all players!")
        }
        
        createPlayerWithLoadingAndPlay(padButtonName: senderPadButtonName)

        //Loop pad every 130 secods to meet duration of audio clip
        timer = Timer.scheduledTimer(timeInterval: 130, target: self, selector: #selector(timerAction(sender:)), userInfo: senderPadButtonName, repeats: true)
    }
    
    func createPlayerWithLoadingAndPlay(padButtonName: String) {
        guard let file = loadAudioFile(fileName: padButtonName) else { return }
        padPlayer = createPlayer(audioFile: file)
        padPlayer.play()
        playerArray.append(padPlayer)
    }

    func loadAudioFile(fileName: String) -> AKAudioFile? {
        var audioFile: AKAudioFile?
        do {
            try audioFile = AKAudioFile(readFileName: "Audio Files/Pads/\(fileName).mp3")
        } catch let err {
            AKLog("Couldn't load audio file: \(fileName).mp3 due to: \(err)")
        }
        return audioFile
    }

    func createPlayer(audioFile: AKAudioFile) -> AKPlayer {
        let player = AKPlayer()
        player.load(audioFile: audioFile)
        player.isLooping = false
        player.pan = padsArePanned ? 1 :  0
        player.fade.inTime = 6 // in seconds
        //player.fade.outTime = 2 //Now handled in the stopFade() method in viewController
        player >>> submixPads
        player.completionHandler = {
            player.detach()
        }
        return player
    }
    
    func stopPadsPlayer() {
        for player in playerArray {
            player.fadeOutAndStop(time: 6)
        }
        shouldLoop = false
        timer.invalidate()
    }

    // MARK: - Signal routing methods
    func performAllRouting() {
        for click in clicksCuesSequencer.clicks.clicksArray {
            click >>> submixClicks
        }
        for cue in clicksCuesSequencer.cues.cuesArray {
            cue >>> submixCues
        }
        submixClicks >>> mixer
        submixCues >>> mixer
        submixPads >>> mixer
        clicksCuesSequencer.callbackInstr >>> mixer
    }
    
    func routeAudioKitToMixer() {
        AudioKit.output = mixer
    }

    // MARK: - Sequencer methods
    func runPlaybackClicksCuesSequencer(fromSong: Song, isSubdivided: Bool) {
        if shouldCountIn == true {
            clicksCuesSequencer.playCountinsAndqDrive(whatSong: fromSong, subDivided: isSubdivided)
        } else if shouldCountIn == false {
            clicksCuesSequencer.qDrive(whatSong: fromSong)
        }
    }

    func startSequencer() {
        clicksCuesSequencer.sequencer.play()
    }

    func stopClicksCuesSequencerAndClearCallback() {
        clicksCuesSequencer.sequencerStopRewindAndClearCallback()
    }

    //MARK: - Signal adjustment methods
    func panAll(whichWay: Bool) {
        switch whichWay {
        case false :
            padsArePanned = false
            clicksCuesSequencer.clicks.clicksPan(pan: 0.0)
            clicksCuesSequencer.cues.cuesPan(pan: 0.0)
            for player in playerArray {
                player.pan = 0.0
            }
        case true :
            padsArePanned = true
            clicksCuesSequencer.clicks.clicksPan(pan: -1.0)
            clicksCuesSequencer.cues.cuesPan(pan: -1.0)
            for player in playerArray {
                player.pan = 1.0
            }
        }
    }

    func changeSubmixVolume(whatSubmix: AKMixer, whatVolume: Double) {
        whatSubmix.volume = whatVolume
    }
    
    func changeVolumeFocusTo(whichClicks: Int) {
        clicksCuesSequencer.clicks.clicksFocusedVolume(whichClicks: whichClicks)
    }

}

