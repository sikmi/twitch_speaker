# encoding: utf-8
require 'rubygems'
require 'fssm'
require 'diff/lcs'
require "strscan"

# 英語と判断する文字数
THRESHOLD = 4

# スピーカー名
SPEAKER_ENGLISH  = "Vicki"
SPEAKER_JAPANESE = "Kyoko"                  

# 発音スピード
RATE_ENGLISH  = 180
RATE_JAPANESE = 180

# 入出力
class Io
  def self.fRead(path)
    f = File.open(path, 'r')
    body = f.read()
    f.close()
    return body.split("\n")
  end
end

class Speaker
  def self.say(message)
    tmp  = message.split(" ",2)
    tmp1 = tmp[1].split(":",2)

    date = tmp[0]
    name = tmp1[0]
    body = tmp1[1]

    if body != nil and name.split(" ").size == 1 then
      parse(body).each do |segment, type|                       
        if type == :alpha && segment.size >= THRESHOLD
          segment = "[[RATE #{RATE_ENGLISH}]] " + segment.gsub("'", "\\'")
          `echo '#{segment}' | say -v '#{SPEAKER_ENGLISH}'`
        else
          segment = "[[RATE #{RATE_JAPANESE}]] " + segment.gsub("'", "\\'")
          `echo '#{segment}' | say -v '#{SPEAKER_JAPANESE}'`
        end
      end
    end
  end

  def self.parse(str)
    str.encode!("UTF-8")
    segments = [] 
    scanner = StringScanner.new(str.gsub(/(\n|\r)+/, " "))
    while true
      # 数字/記号の判断を一旦保留
      if scanner.scan(/[\d\s!-\/:-@\[-`{-~]+/)
        segments << [scanner[0], :num]
        # 続く文字列が英字であれば英字文字列の一部とみなす
      elsif scanner.scan(/[A-z][!-~\s]*/)
        if segments[-1] && segments[-1][1] == :num
          num = segments.pop[0]
          segment = num + scanner[0]
        else
          segment = scanner[0]
        end
        segments << [segment, :alpha]
        # それ以外は日本語文字列の一部とみなす
      elsif scanner.scan(/[^A-z]+/)
        if segments[-1] && segments[-1][1] == :num
          num = segments.pop[0]
          segment = num + scanner[0]
        else
          segment = scanner[0]
        end
        segments << [segment, :nonalpha]
      else
        break
      end
    end  
    return segments
  end
end

class TwitchSpeaker

  def initialize
    @defaultTranscripts = "#{File.expand_path("~")}/Documents/LimeChat Transcripts/"
    channel = ARGV[0]
    if channel == nil then
      dir = nil
    else
      dir = @defaultTranscripts + channel
    end
    @pathDir, @pathLog = selectLog(dir)
  end

  def selectLog(dir=nil)
    pattern = "#{dir}/#{Time.now.strftime("%Y-%m-%d")}*"
    log = ''
    Dir.glob(pattern) do |f|
      log = f
    end
    return dir+'/',log
  end

  def watch
    prevLog = Io.fRead(@pathLog)
    FSSM.monitor(File.dirname(@pathLog)) do
      update do |basedir, filename|
        p basedir, filename
        currLog = Io.fRead("#{basedir}/#{filename}")
        diffs = Diff::LCS.sdiff(prevLog, currLog)
        diffs.each do |diff|
          if diff.action == '+' or diff.action == '!' then
            message = diff.new_element
            Speaker.say(message)
          end
        end
        prevLog = currLog
      end
      create do |basedir, filename|
        p basedir, filename
        @pathLog = "#{basedir}/#{filename}"
        p @pathLog
        prevLog = []
        currLog = Io.fRead(@pathLog)
        diffs = Diff::LCS.sdiff(prevLog, currLog)
        diffs.each do |diff|
          if diff.action == '+' or diff.action == '!' then
            message = diff.new_element
            Speaker.say(message)
          end
        end
        prevLog = currLog
      end
    end
  end
end

twitch_speaker = TwitchSpeaker.new
twitch_speaker.watch

