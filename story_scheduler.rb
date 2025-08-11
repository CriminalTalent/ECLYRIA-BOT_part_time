# story_scheduler.rb
require 'time'
require 'date'

class StoryScheduler
  def initialize(sheet_manager, story_manager)
    @sheet_manager = sheet_manager
    @story_manager = story_manager
    @active_schedules = {} # 진행 중인 스케줄 캐시
  end

  # 스케줄 체크 및 실행
  def check_and_execute_schedules
    schedules = load_active_schedules
    current_time = Time.now
    
    schedules.each do |schedule|
      schedule_id = schedule["ID"]
      
      begin
        case schedule["상태"]
        when "대기"
          check_start_time(schedule, current_time)
        when "진행중"
          check_next_story(schedule, current_time)
        when "완료", "중지"
          # 완료/중지된 스케줄은 건너뛰기
          next
        end
      rescue => e
        puts "[에러] 스케줄 #{schedule_id} 처리 중 에러: #{e.message}"
        # 해당 스케줄을 중지 상태로 변경
        update_schedule_status(schedule_id, "중지", "에러 발생: #{e.message}")
      end
    end
  end

  private

  # 활성 스케줄 로드
  def load_active_schedules
    values = @sheet_manager.read_values("스케줄!A:J")
    return [] if values.nil? || values.empty?
    
    headers = values[0]
    schedules = []
    
    values.each_with_index do |row, index|
      next if index == 0 # 헤더 스킵
      next if row[0].nil? || row[0].empty? # ID가 없는 행 스킵
      
      schedule = {}
      headers.each_with_index do |header, col_index|
        schedule[header] = row[col_index]
      end
      
      # 대기 또는 진행중인 스케줄만 포함
      if ["대기", "진행중"].include?(schedule["상태"])
        schedules << schedule
      end
    end
    
    schedules
  end

  # 시작 시간 체크
  def check_start_time(schedule, current_time)
    schedule_id = schedule["ID"]
    start_date = schedule["시작날짜"]
    start_time = schedule["시작시간"]
    
    return unless start_date && start_time
    
    begin
      # 시작 시간 파싱
      start_datetime = Time.parse("#{start_date} #{start_time}")
      
      if current_time >= start_datetime
        puts "[스케줄] #{schedule_id} 시작: #{schedule['제목']}"
        
        # 상태를 '진행중'으로 변경
        update_schedule_status(schedule_id, "진행중")
        
        # 첫 번째 스토리 즉시 발송
        send_next_story(schedule)
      else
        time_diff = start_datetime - current_time
        puts "[대기] #{schedule_id}: #{(time_diff / 60).to_i}분 후 시작"
      end
      
    rescue => e
      puts "[에러] #{schedule_id} 시간 파싱 실패: #{e.message}"
    end
  end

  # 다음 스토리 체크
  def check_next_story(schedule, current_time)
    schedule_id = schedule["ID"]
    interval_minutes = (schedule["간격"] || "60").to_i
    current_progress = (schedule["현재진행"] || "0").to_i
    total_count = (schedule["총횟수"] || "1").to_i
    last_sent = schedule["마지막발송"]
    
    # 모든 스토리 발송 완료 체크
    if current_progress >= total_count
      puts "[완료] #{schedule_id}: 모든 스토리 발송 완료"
      update_schedule_status(schedule_id, "완료")
      return
    end
    
    # 마지막 발송 시간 체크
    if last_sent && !last_sent.empty?
      begin
        last_sent_time = Time.parse(last_sent)
        next_send_time = last_sent_time + (interval_minutes * 60)
        
        if current_time >= next_send_time
          send_next_story(schedule)
        else
          time_diff = next_send_time - current_time
          puts "[대기] #{schedule_id}: #{(time_diff / 60).to_i}분 후 다음 스토리"
        end
      rescue => e
        puts "[에러] #{schedule_id} 마지막발송시간 파싱 실패: #{e.message}"
        # 파싱 실패 시 즉시 다음 스토리 발송
        send_next_story(schedule)
      end
    else
      # 마지막 발송 시간이 없으면 즉시 발송 (첫 번째 스토리)
      send_next_story(schedule)
    end
  end

  # 다음 스토리 발송
  def send_next_story(schedule)
    schedule_id = schedule["ID"]
    current_progress = (schedule["현재진행"] || "0").to_i
    next_story_order = current_progress + 1
    
    # 스토리 발송
    success = @story_manager.send_story(schedule_id, next_story_order)
    
    if success
      # 진행 상태 업데이트
      current_time = Time.now.strftime('%Y-%m-%d %H:%M:%S')
      update_schedule_progress(schedule_id, next_story_order, current_time)
      
      puts "[발송] #{schedule_id}: #{next_story_order}번째 스토리 발송 완료"
    else
      puts "[실패] #{schedule_id}: #{next_story_order}번째 스토리 발송 실패"
    end
  end

  # 스케줄 상태 업데이트
  def update_schedule_status(schedule_id, status, note = nil)
    values = @sheet_manager.read_values("스케줄!A:J")
    return unless values && values.length > 1
    
    values.each_with_index do |row, index|
      next if index == 0
      if row[0] == schedule_id
        row_num = index + 1
        
        # H열: 상태
        @sheet_manager.update_values("스케줄!H#{row_num}", [[status]])
        
        # J열: 비고 (에러 메시지 등)
        if note
          @sheet_manager.update_values("스케줄!J#{row_num}", [[note]])
        end
        
        break
      end
    end
  end

  # 스케줄 진행 상태 업데이트
  def update_schedule_progress(schedule_id, progress, last_sent_time)
    values = @sheet_manager.read_values("스케줄!A:J")
    return unless values && values.length > 1
    
    values.each_with_index do |row, index|
      next if index == 0
      if row[0] == schedule_id
        row_num = index + 1
        
        # G열: 현재진행
        @sheet_manager.update_values("스케줄!G#{row_num}", [[progress]])
        
        # I열: 마지막발송
        @sheet_manager.update_values("스케줄!I#{row_num}", [[last_sent_time]])
        
        break
      end
    end
  end

  # 수동 스케줄 제어 메서드들
  def pause_schedule(schedule_id)
    update_schedule_status(schedule_id, "중지", "수동 일시정지")
    puts "[제어] #{schedule_id} 스케줄 일시정지"
  end

  def resume_schedule(schedule_id)
    update_schedule_status(schedule_id, "진행중", "수동 재개")
    puts "[제어] #{schedule_id} 스케줄 재개"
  end

  def complete_schedule(schedule_id)
    update_schedule_status(schedule_id, "완료", "수동 완료")
    puts "[제어] #{schedule_id} 스케줄 완료"
  end

  # 스케줄 현황 조회
  def get_schedule_status
    schedules = load_active_schedules
    
    if schedules.empty?
      return "진행 중인 스케줄이 없습니다."
    end
    
    status_text = "=== 스케줄 현황 ===\n"
    schedules.each do |schedule|
      progress = "#{schedule['현재진행'] || 0}/#{schedule['총횟수'] || 0}"
      status_text += "#{schedule['ID']}: #{schedule['제목']} (#{progress}) - #{schedule['상태']}\n"
    end
    
    status_text
  end
end
