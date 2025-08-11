# main.rb - 스토리 진행 봇
require 'dotenv/load'
require 'google/apis/sheets_v4'
require 'googleauth'
require 'set'
require_relative 'mastodon_client'
require_relative 'sheet_manager'
require_relative 'story_scheduler'
require_relative 'story_manager'
require_relative 'admin_commands'

# 봇 시작 시간 기록
BOT_START_TIME = Time.now
puts "[스토리봇] 실행 시작 (#{BOT_START_TIME.strftime('%Y-%m-%d %H:%M:%S')})"

# Google Sheets 서비스 초기화
begin
  sheets_service = Google::Apis::SheetsV4::SheetsService.new
  credentials = Google::Auth::ServiceAccountCredentials.make_creds(
    json_key_io: File.open('credentials.json'),
    scope: 'https://www.googleapis.com/auth/spreadsheets'
  )
  credentials.fetch_access_token!
  sheets_service.authorization = credentials
  spreadsheet = sheets_service.get_spreadsheet(ENV["GOOGLE_SHEET_ID"])
  puts "[스토리봇] Google Sheets 연결 성공: #{spreadsheet.properties.title}"
rescue => e
  puts "[스토리봇] Google Sheets 연결 실패: #{e.message}"
  exit
end

# 시트 매니저 초기화
sheet_manager = SheetManager.new(sheets_service, ENV["GOOGLE_SHEET_ID"])

# 마스토돈 클라이언트 초기화
mastodon = MastodonClient.new(
  base_url: ENV['MASTODON_BASE_URL'],
  token: ENV['MASTODON_TOKEN']
)

# 스토리 매니저 초기화
story_manager = StoryManager.new(mastodon, sheet_manager)

# 스토리 스케줄러 초기화
scheduler = StoryScheduler.new(sheet_manager, story_manager)

# 관리자 명령어 처리기 초기화
admin_commands = AdminCommands.new(mastodon, sheet_manager, scheduler, story_manager)

# 봇 상태 확인
bot_status = sheet_manager.get_setting("봇상태")
if bot_status != "활성"
  puts "[스토리봇] 봇이 비활성 상태입니다. 시트에서 '봇상태'를 '활성'으로 변경해주세요."
  exit
end

puts "[스토리봇] 스케줄러 시작..."

# 처리된 멘션 ID 추적 (중복 방지)
processed_mentions = Set.new

# 멘션 스트리밍을 별도 스레드에서 실행
mention_thread = Thread.new do
  begin
    puts "[스토리봇] 멘션 스트리밍 시작..."
    mastodon.stream_user do |mention|
      begin
        # 멘션 ID로 중복 처리 방지
        mention_id = mention.id
        if processed_mentions.include?(mention_id)
          puts "[무시] 이미 처리된 멘션: #{mention_id}"
          next
        end
        
        # 봇 시작 시간 이전의 멘션은 무시
        mention_time = Time.parse(mention.status.created_at)
        if mention_time < BOT_START_TIME
          puts "[무시] 봇 시작 이전 멘션: #{mention_time.strftime('%H:%M:%S')}"
          next
        end

        # 멘션 ID 기록
        processed_mentions.add(mention_id)
        
        sender_full = mention.account.acct
        content = mention.status.content
        
        puts "[멘션] #{mention_time.strftime('%H:%M:%S')} - @#{sender_full}"
        puts "[내용] #{content}"
        
        # 관리자 명령어 처리
        admin_commands.handle_mention(mention)
        
      rescue => e
        puts "[에러] 멘션 처리 중 예외 발생: #{e.message}"
        puts e.backtrace.first(3)
      end
    end
  rescue => e
    puts "[에러] 멘션 스트리밍 에러: #{e.message}"
    sleep 10
    retry
  end
end

# 메인 스케줄러 루프
begin
  # 스케줄 체크 간격 (기본 60초)
  check_interval = (sheet_manager.get_setting("체크간격") || "60").to_i
  
  loop do
    begin
      # 봇 상태 재확인
      current_status = sheet_manager.get_setting("봇상태")
      if current_status != "활성"
        puts "[스토리봇] 봇이 비활성화되었습니다. 종료합니다."
        break
      end
      
      # 스케줄 체크 및 실행
      scheduler.check_and_execute_schedules
      
      # 대기
      sleep(check_interval)
      
    rescue => e
      puts "[에러] 메인 루프 에러: #{e.message}"
      puts e.backtrace.first(3)
      sleep(check_interval) # 에러 발생해도 계속 동작
    end
  end
  
rescue Interrupt
  puts "\n[스토리봇] 봇 종료 신호를 받았습니다."
rescue => e
  puts "[치명적 에러] #{e.message}"
  puts e.backtrace
ensure
  # 멘션 스레드 종료
  if mention_thread && mention_thread.alive?
    mention_thread.kill
  end
  puts "[스토리봇] 봇을 종료합니다."
end
