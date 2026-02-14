#!/usr/bin/env ruby
# encoding: UTF-8

require 'dotenv/load'
require 'google/apis/sheets_v4'
require 'googleauth'

require_relative 'mastodon_client'
require_relative 'sheet_manager'
require_relative 'command_parser'

BASE_URL = ENV['MASTODON_BASE_URL']
TOKEN = ENV['MASTODON_TOKEN']
SHEET_ID = ENV['GOOGLE_SHEET_ID']
CRED_PATH = ENV['GOOGLE_CREDENTIALS_PATH']
LAST_FILE = 'last_mention_id.txt'

if [BASE_URL, TOKEN, SHEET_ID, CRED_PATH].any? { |v| v.nil? || v.empty? }
  puts "[에러] 환경변수 누락"
  exit 1
end

puts "[아르바이트봇] 시작 (#{Time.now.strftime('%Y-%m-%d %H:%M:%S')})"

begin
  service = Google::Apis::SheetsV4::SheetsService.new
  service.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
    json_key_io: File.open(CRED_PATH),
    scope: ['https://www.googleapis.com/auth/spreadsheets']
  )
  sheet_manager = SheetManager.new(service, SHEET_ID)
  puts "[Google Sheets] 연결 성공"
rescue => e
  puts "[에러] Google Sheets 연결 실패: #{e.message}"
  exit 1
end

begin
  client = MastodonClient.new(base_url: BASE_URL, token: TOKEN)
  puts "[마스토돈] 클라이언트 초기화 완료"
rescue => e
  puts "[에러] 마스토돈 연결 실패: #{e.message}"
  exit 1
end

begin
  latest = client.notifications(limit: 1)
  if latest && latest.any?
    last_id = latest.first["id"].to_i
    File.write(LAST_FILE, last_id.to_s)
    puts "[초기화] 최신 ID: #{last_id}"
  else
    last_id = File.exist?(LAST_FILE) ? File.read(LAST_FILE).to_i : 0
  end
rescue => e
  puts "[에러] 초기화 실패: #{e.message}"
  last_id = 0
end

puts "[대기] 멘션 감시 시작..."
puts "━" * 30

loop do
  begin
    notifications = client.notifications(limit: 30)
    
    notifications.reverse_each do |n|
      nid = n["id"].to_i
      next unless nid > last_id
      next unless n["type"] == "mention"

      last_id = nid
      File.write(LAST_FILE, last_id.to_s)

      account = n["account"]
      sender = account["acct"]
      content_raw = n.dig("status", "content") || ""

      puts "\n[#{Time.now.strftime('%H:%M:%S')}] 멘션 수신"
      puts "  발신: @#{sender}"
      puts "  내용: #{content_raw[0..50]}..."

      CommandParser.parse(client, sheet_manager, n)

      sleep 2
    end

  rescue => e
    puts "[에러] 메인 루프: #{e.class} - #{e.message}"
    puts e.backtrace.first(3).join("\n")
  end

  sleep 8
end
