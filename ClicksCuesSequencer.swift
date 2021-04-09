//
//  Sequencer.swift
//  SequencerDemo
//
//  Created by Q LIVE, LLC on 7/7/19.
//  Copyright © 2019 Q LIVE, LLC. All rights reserved.
//

import Foundation
import AudioKit

extension Constant {
    static var clickVelocity: MIDIVelocity = MIDIVelocity(100)
    static var clickNote: MIDINoteNumber = MIDINoteNumber(60)
    static var noteOnStatus = 0x90
    static var clickBeatDuration: AKDuration = AKDuration(beats: 1)
}

extension AKMIDISampler {
    func playClick() throws {
        try play(noteNumber: Constant.clickNote, velocity: Constant.clickVelocity, channel: 1)
    }
}

class ClicksCuesSequencer {
    //Reset location on sequencer for each playback instance
    var currentBeat = 0
    var countInSelected = true

    let sequencer = AKSequencer()
    var callbackTrack: AKSequencerTrack!
    let callbackInstr = AKCallbackInstrument()
    var cues = Cues()
    let countIn = CountIn()

    var clicks = Clicks()

    func addCallbackTrackToSequencer() {
        callbackTrack = sequencer.addTrack(for: callbackInstr)
        callbackTrack.length = 100000//seems to be required to prevent looping
    }

    func clearSequencerIncludingCallbackTracks() {
        sequencer.clear()
        callbackTrack.clear()
    }
    
    func reconnectClicks(){
        var clicks = Clicks()
    }
    func reconnectCues() {
        var cues = Cues()
    }

    func setupCallbackWithSong() {
        let viewModel = ViewModel.sharedInstance
            callbackInstr.callback = { status, noteNumber, velocity in
            guard status == Constant.noteOnStatus else { return }
            self.callbackPlaybackSwitch(playbackNote: noteNumber, playbackSong: viewModel.activeSong)
        }
    }

    func playCountinsAndqDrive(whatSong: Song, subDivided: Bool) {
        sequencer.tempo = (Double(whatSong.songMeasures[0].tempo))
        if whatSong.subDivided == true {
            for beats in countIn.countInSwitchSubdivided(whatTimeSignature: whatSong.songMeasures[0].timeSignature) {
                currentBeat += 1
                for notes in beats {
                    callbackTrack?.add(noteNumber: MIDINoteNumber(notes), position: Double(currentBeat),
                                       duration: Constant.clickBeatDuration.beats)
                }
            }
            callbackTrack?.add(noteNumber: MIDINoteNumber(100), position: Double(currentBeat),
                               duration: Constant.clickBeatDuration.beats)
        } else {
        for beats in countIn.countInSwitchStandard(whatTimeSignature: whatSong.songMeasures[0].timeSignature) {
            currentBeat += 1
            for notes in beats {
                callbackTrack?.add(noteNumber: MIDINoteNumber(notes), position: Double(currentBeat),
                                   duration: Constant.clickBeatDuration.beats)
            }
        }
        callbackTrack?.add(noteNumber: MIDINoteNumber(100), position: Double(currentBeat),
                           duration: Constant.clickBeatDuration.beats)
        }
    }

    func qDrive(whatSong: Song) {
        print("currentBeat: \(currentBeat)")
        sequencer.tempo = (Double(whatSong.songMeasures[0].tempo))
        for beats in whatSong.songMeasures[0].beats {
            currentBeat += 1
            for notes in beats {
                callbackTrack?.add(noteNumber: MIDINoteNumber(notes), position: Double(currentBeat),
                                   duration: Constant.clickBeatDuration.beats)
            }
        }
        callbackTrack?.add(noteNumber: MIDINoteNumber(100), position: Double(currentBeat),
                           duration: Constant.clickBeatDuration.beats)
    }

    func sequencerStopRewindAndClearCallback() {
        sequencer.stop()
        sequencer.rewind()
        callbackTrack.clear()
        currentBeat = 0
    }

    //Check MIDI note received from the callback track in real time and play AKMIDISequencer accordingly
    func callbackPlaybackSwitch(playbackNote: UInt8, playbackSong: Song) {
        print("callbackPlaybackSwitch is passing in \(playbackNote)")
        switch playbackNote {
        case 0:
            print("")
            //Clicks
        case 1:
            try? clicks.clickhigh.playClick()
            try? clicks.shakerHigh.playClick()
            try? clicks.blockHigh.playClick()
            NotificationCenter.default.post(name: Notification.Name(Constant.flashButtonNoRepeatNotification), object: nil)
        case 2:
            try? clicks.clicklow.playClick()
            try? clicks.shakerLow.playClick()
            try? clicks.blockLow.playClick()
            NotificationCenter.default.post(name: Notification.Name(Constant.flashButtonNoRepeatNotification), object: nil)
//            Cues
        case 11:
            try? cues.cueOne44.playClick()
        case 12:
            try? cues.cueTwo44.playClick()
        case 13:
            try? cues.cueThree44.playClick()
        case 14:
            try? cues.cueFour44.playClick()
        case 15:
            try? cues.cueFive68.playClick()
        case 16:
            try? cues.cueSix68.playClick()
        case 17:
            try? cues.cueSeven.playClick()
        case 18:
            try? cues.cueEight.playClick()
        case 21:
            try? cues.cueOne68.playClick()
        case 22:
            try? cues.cueTwo68.playClick()
        case 23:
            try? cues.cueThree68.playClick()
        case 24:
            try? cues.cueFour68.playClick()
        case 25:
            try? cues.cueFive68.playClick()
        case 26:
            try? cues.cueSix68.playClick()
        case 100:
            //Run again after measure runs out of beats
            print("loop from callbackPlaybackSwitch!")
            qDrive(whatSong: playbackSong)
        default:
            print("issue at the switch")
        }

    }
}
