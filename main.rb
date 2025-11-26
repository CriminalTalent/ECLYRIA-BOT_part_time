#!/usr/bin/env ruby
# main.rb - 호그와트 아르바이트 봇

$stdout.sync = true
$stderr.sync = true

require 'dotenv/load'
require 'time'
require 'json'
require 'set'

require_relative 'mastodon_client'
require_relative 'sheet_manager'
require_relative 'command_parser'

# 환경변수 확인
required_envs = %w[MASTODON_BASE_URL MASTODON_TOKEN GOOGLE_SHEET_ID GOOGLE_CREDENTIALS_PATH]
missing = required_envs.select { |v| ENV[v].nil? || ENV[v].strip.empty? }

if missing.any?
  puts "[오류] 필수 환경변수 누락: #{missing.join(', ')}"
  puts ".env 파일을 확인해주세요."
  exit 1
end

BOT_START_TIME = Time.now
puts "[아르바이트봇] 시작 (#{BOT_START_TIME.strftime('%Y-%m-%d %H:%M:%S')})"

# Google Sheets 연결
begin
  sheet_manager = SheetManager.new(
    ENV['GOOGLE_SHEET_ID'],
    ENV['GOOGLE_CREDENTIALS_PATH']
  )
  puts "[Google Sheets] 연결 성공"
rescue => e
  puts "[오류] Google Sheets 연결 실패: #{e.message}"
  exit 1
end

# 마스토돈 클라이언트
mastodon = MastodonClient.new(
  base_url: ENV['MASTODON_BASE_URL'],
  token: ENV['MASTODON_TOKEN']
)
puts "[마스토돈] 클라이언트 초기화 완료"

# 명령어 파서
parser = CommandParser.new(mastodon, sheet_manager)

# 마지막 처리 ID 파일
LAST_ID_FILE = 'last_mention_id.txt'
last_id = File.exist?(LAST_ID_FILE) ? File.read(LAST_ID_FILE).strip : nil

# 이미 처리한 멘션 ID 추적 (메모리)
processed_ids = Set.new

puts "[대기] 멘션 감시 시작..."
puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 메인 루프
loop do
  begin
    mentions = mastodon.fetch_mentions(since_id: last_id)
    
    # 최신순으로 정렬 (오래된 것부터 처리)
    mentions = mentions.sort_by { |m| m['id'].to_i }
    
    mentions.each do |mention|
      next unless mention['type'] == 'mention'
      next unless mention['status']
      
      mention_id = mention['id']
      
      # 이미 처리한 멘션은 건너뛰기
      next if processed_ids.include?(mention_id)
      
      created_at = Time.parse(mention['status']['created_at'])
      
      # 봇 시작 전 멘션은 무시
      next if created_at < BOT_START_TIME
      
      sender = mention['account']['acct']
      content = mention['status']['content'].gsub(/<[^>]*>/, '').strip
      
      puts "\n[#{Time.now.strftime('%H:%M:%S')}] 멘션 수신"
      puts "  발신: @#{sender}"
      puts "  내용: #{content[0..50]}..."
      
      # 명령어 처리
      parser.parse(mention)
      
      # 처리 완료 기록
      processed_ids.add(mention_id)
      last_id = mention_id
      File.write(LAST_ID_FILE, last_id)
    end
    
  rescue => e
    puts "[오류] #{e.class}: #{e.message}"
    puts e.backtrace.first(3)
    sleep 5
  end
  
  # 30초 대기
  sleep 30
end
