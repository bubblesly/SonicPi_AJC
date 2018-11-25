class Lfo
  def initialize(parent, ratio)
    @parent = parent
    @step = 0.1
    @buff = @parent.range(-1, 1, @step).mirror
    @value = -1
    @parent.in_thread do
      loop do
        @value = @buff.tick
        @parent.sleep(@step * ratio)
      end
    end
  end
  
  def look()
    @value
  end
  
end

class Synth
  def initialize(parent, lfo, cutoff_min, cutoff_max, res, note_length)
    @parent = parent
    @cutoff_min = cutoff_min
    @cutoff_max = cutoff_max
    @res = res
    @lfo = lfo
  end
  
  def play(n)
    if n != :none then
      @parent.use_synth :tb303
      @cutoff = (@lfo.look() + 1) * 0.5 * (@cutoff_max - @cutoff_min) + @cutoff_min
      @parent.with_fx :distortion do
        @parent.play(n,
                     attack: 0.0, decay: 0.25, sustain: 0, sustain_level: 0, release: 0,
                     cutoff_attack: 0.1, cutoff_decay: 0.2, cutoff_sustain: 0, cutoff_release: 0,
                     wave: :square, cutoff: @cutoff, res: @res)
      end
    end
  end
  
end

class Sample
  def initialize(parent, sample_name, a: 0, d: 0, s: 1, r: 1)
    @parent = parent
    @a = a
    @d = d
    @s = s
    @r = r
    @sample_name = sample_name
  end
  
  def play(n)
    if n == :x
      @parent.sample @sample_name,
        attack: @a, decay: @d,
        sustain_level: @s, release: @r,
        amp: 2
    end
  end
end

class Sequence
  def initialize(parent, instrument, seq, repetitions = -1)
    @parent = parent
    @patternId = nil
    @played = false
    @instrument = instrument
    @seq = seq.ring
    @repetitions = repetitions
  end
  
  def setPatternId(patternId)
    @patternId = patternId
  end
  
  def played?()
    @played
  end
  
  def play(bpm)
    if @repetitions > 0
      repeat(@repetitions, bpm)
    else
      seqLoop(bpm)
    end
  end
  
  def seqLoop(bpm)
    @parent.in_thread do
      @parent.use_bpm bpm
      while !played?
        playNextNote()
      end
    end
  end
  
  def repeat(r, bpm)
    @parent.in_thread do
      @parent.use_bpm bpm
      (r * @seq.size * 0.5).times do
        playNextNote()
      end
      @played = true
      if @patternId != nil
        @parent.cue @patternId
      end
    end
  end
  
  def playNextNote()
    @instrument.play(@seq.tick)
    @parent.sleep noteLengthToDuration(@seq.tick)
  end
  
  def noteLengthToDuration(l)
    case l
    when :n_w
      4
    when :n_h
      2
    when :n_h_dotted
      3
    when :n_q
      1
    when :n_q_dotted
      1.5
    when :n_8th
      0.5
    when :n_8th_dotted
      0.75
    when :n_16th
      0.25
    when :n_16th_dotted
      0.375
    when :n_32nd
      0.125
    else
      1
    end
  end
end

class Pattern
  
  def initialize(parent, patternId, playedSignal)
    @parent = parent
    @patternId = patternId
    @playedSignal = playedSignal
    @sequences = []
  end
  
  def addSequence(s)
    s.setPatternId(@patternId)
    @sequences.push(s)
  end
  
  def play(bpm)
    @parent.in_thread do
      @sequences.each do |s|
        s.play(bpm)
      end
      while !played?
        @parent.sync @patternId
      end
      @parent.cue @playedSignal
    end
  end
  
  def played?()
    played = true
    @sequences.each do |s|
      played = played && s.played?
    end
    played
  end
end


bpm = 100
lfo = Lfo.new(self, 0.5)
synth = Synth.new(self, lfo, 70, 130, 0.9, 0.25)

kick    = Sample.new(self, :drum_heavy_kick)
snare   = Sample.new(self, :drum_snare_hard)
pedalHh = Sample.new(self, :drum_cymbal_pedal)
openHh  = Sample.new(self, :drum_cymbal_open, a: 0, d: 0.25, s: 0, r: 0)

intro = Pattern.new(self, :intro, :intro_played)
intro.addSequence(Sequence.new(self, synth,   [:none, :n_16th, :c4, :n_16th, :a2, :n_8th, :a3, :n_8th, :a2 , :n_8th, :c3, :n_8th, :d3, :n_16th, :e3, :n_8th_dotted, :a2, :n_8th], 4))



verse = Pattern.new(self, :verse, :verse_played)
verse.addSequence(Sequence.new(self, kick,    [:x, :n_8th, :o, :n_8th, :x, :n_8th, :o, :n_8th, :x, :n_8th, :o, :n_8th, :x, :n_8th, :o, :n_8th], 8))
verse.addSequence(Sequence.new(self, snare,   [:o, :n_8th, :o, :n_8th, :x, :n_8th, :o, :n_8th, :o, :n_8th, :o, :n_8th, :x, :n_8th, :o, :n_8th], 8))
verse.addSequence(Sequence.new(self, pedalHh, [:x, :n_8th, :o, :n_8th, :x, :n_8th, :o, :n_8th, :x, :n_8th, :o, :n_8th, :x, :n_8th, :o, :n_8th], 8))
verse.addSequence(Sequence.new(self, openHh,  [:o, :n_8th, :o, :n_8th, :o, :n_8th, :o, :n_8th, :o, :n_8th, :o, :n_8th, :o, :n_8th, :x, :n_8th], 8))
verse.addSequence(Sequence.new(self, synth,   [:none, :n_16th, :c4, :n_16th, :a2, :n_8th, :a3, :n_8th, :a2 , :n_8th, :c3, :n_8th, :d3, :n_16th, :e3, :n_8th_dotted, :a2, :n_8th], 8))


intro.play(bpm)
sync :intro_played
verse.play(bpm)
sync :verse_played


