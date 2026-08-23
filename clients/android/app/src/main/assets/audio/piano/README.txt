Acoustic Grand Piano samples from MusyngKite via midi-js-soundfonts
Source: https://gleitz.github.io/midi-js-soundfonts/MusyngKite/acoustic_grand_piano-mp3/
License: see third_party/soundfonts/MIDI_JS_SOUNDFONTS_LICENSE.txt
Mapped as n{midi}.wav (mono 22050 Hz PCM) for MIDI 21–108 (A0–C8).
Peaks in the source MP3s are very low; ScoreAudioPlayer applies
PracticeConstants.sampleGain with soft-clip when building the play cache.
Regenerate: python scripts/download_piano_samples.py && python scripts/boost_piano_samples.py
