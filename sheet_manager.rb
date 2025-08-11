# sheet_manager.rb - 스토리 봇용 확장
require 'google/apis/sheets_v4'

class SheetManager
  def initialize(sheets_service, sheet_id)
    @service = sheets_service
    @sheet_id = sheet_id
    @worksheets_cache = {}
    @settings_cache = {} # 설정 캐시
  end

  # 기존 API v4 메서드들
  def read_values(range)
    @service.get_spreadsheet_values(@sheet_id, range).values
  rescue => e
    puts "시트 읽기 오류: #{e.message}"
    []
  end

  def update_values(range, values)
    puts "[DEBUG] 업데이트 시도: 범위=#{range}, 값=#{values.inspect}"
    value_range = Google::Apis::SheetsV4::ValueRange.new(values: values)
    result = @service.update_spreadsheet_value(@sheet_id, range, value_range, value_input_option: 'USER_ENTERED')
    puts "[DEBUG] 업데이트 결과: #{result.updated_cells}개 셀 업데이트됨"
    result
  rescue => e
    puts "시트 쓰기 오류: #{e.message}"
    puts e.backtrace.first(3)
    nil
  end

  def append_values(range, values)
    puts "[DEBUG] 추가 시도: 범위=#{range}, 값=#{values.inspect}"
    value_range = Google::Apis::SheetsV4::ValueRange.new(values: values)
    result = @service.append_spreadsheet_value(@sheet_id, range, value_range, value_input_option: 'USER_ENTERED')
    puts "[DEBUG] 추가 결과: #{result.updated_rows}개 행 추가됨"
    result
  rescue => e
    puts "시트 추가 오류: #{e.message}"
    nil
  end

  # 스토리 봇 전용 설정 관리
  def get_setting(setting_name)
    # 캐시 확인
    if @settings_cache[setting_name] && 
       @settings_cache[setting_name][:timestamp] > Time.now - 300 # 5분 캐시
      return @settings_cache[setting_name][:value]
    end

    values = read_values("설정!A:C")
    return nil if values.nil? || values.empty?
    
    values.each_with_index do |row, index|
      next if index == 0 # 헤더 스킵
      if row[0] == setting_name
        value = row[1]
        
        # 캐시 저장
        @settings_cache[setting_name] = {
          value: value,
          timestamp: Time.now
        }
        
        return value
      end
    end
    
    nil
  end

  def set_setting(setting_name, value, description = nil)
    values = read_values("설정!A:C")
    
    if values.nil? || values.empty?
      # 설정 시트가 비어있으면 헤더와 함께 추가
      headers = [["항목", "값", "설명"]]
      new_setting = [[setting_name, value, description]]
      update_values("설정!A1:C1", headers)
      append_values("설정!A:C", new_setting)
    else
      # 기존 설정 찾기
      setting_found = false
      
      values.each_with_index do |row, index|
        next if index == 0 # 헤더 스킵
        if row[0] == setting_name
          # 기존 설정 업데이트
          row_num = index + 1
          update_values("설정!B#{row_num}", [[value]])
          if description
            update_values("설정!C#{row_num}", [[description]])
          end
          setting_found = true
          break
        end
      end
      
      # 새 설정 추가
      unless setting_found
        new_setting = [[setting_name, value, description]]
        append_values("설정!A:C", new_setting)
      end
    end
    
    # 캐시 업데이트
    @settings_cache[setting_name] = {
      value: value,
      timestamp: Time.now
    }
    
    puts "[설정] #{setting_name} = #{value}"
  end

  # 모든 설정 조회
  def get_all_settings
    values = read_values("설정!A:C")
    return {} if values.nil? || values.empty?
    
    settings = {}
    values.each_with_index do |row, index|
      next if index == 0 # 헤더 스킵
      settings[row[0]] = {
        value: row[1],
        description: row[2]
      }
    end
    
    settings
  end

  # 설정 캐시 초기화
  def clear_settings_cache
    @settings_cache.clear
    puts "[캐시] 설정 캐시 초기화"
  end

  # 스케줄 통계
  def get_schedule_statistics
    values = read_values("스케줄!A:J")
    return "스케줄 데이터가 없습니다." if values.nil? || values.empty?
    
    total_schedules = values.length - 1 # 헤더 제외
    status_counts = Hash.new(0)
    
    values.each_with_index do |row, index|
      next if index == 0 # 헤더 스킵
      status = row[7] || "알 수 없음" # H열: 상태
      status_counts[status] += 1
    end
    
    stats = "=== 스케줄 통계 ===\n"
    stats += "전체 스케줄: #{total_schedules}개\n"
    status_counts.each do |status, count|
      stats += "#{status}: #{count}개\n"
    end
    
    stats
  end

  # 스토리 통계 (전체)
  def get_story_statistics
    values = read_values("스토리!A:H")
    return "스토리 데이터가 없습니다." if values.nil? || values.empty?
    
    total_stories = values.length - 1 # 헤더 제외
    sent_count = 0
    schedule_counts = Hash.new(0)
    
    values.each_with_index do |row, index|
      next if index == 0 # 헤더 스킵
      
      # 발송 완료 체크
      if row[6] == "Y" # G열: 발송완료
        sent_count += 1
      end
      
      # 스케줄별 카운트
      schedule_id = row[0] # A열: 스케줄ID
      schedule_counts[schedule_id] += 1 if schedule_id
    end
    
    stats = "=== 스토리 통계 ===\n"
    stats += "전체 스토리: #{total_stories}개\n"
    stats += "발송 완료: #{sent_count}개\n"
    stats += "대기 중: #{total_stories - sent_count}개\n"
    stats += "진행률: #{total_stories > 0 ? (sent_count.to_f / total_stories * 100).round(1) : 0}%\n\n"
    
    stats += "스케줄별 스토리 개수:\n"
    schedule_counts.each do |schedule_id, count|
      stats += "#{schedule_id}: #{count}개\n"
    end
    
    stats
  end

  # 로그 기록 (옵션)
  def log_activity(activity_type, details)
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    log_entry = [[timestamp, activity_type, details]]
    
    begin
      append_values("로그!A:C", log_entry)
    rescue => e
      puts "[로그] 기록 실패: #{e.message}"
    end
  end

  # 기존 전투봇 메서드들 (호환성 유지)
  def worksheet_by_title(title)
    @worksheets_cache[title] ||= WorksheetWrapper.new(self, title)
  end

  def worksheet(title)
    worksheet_by_title(title)
  end

  def get_stat(user_id, column_name)
    clean_user_id = user_id.gsub('@', '')
    
    values = read_values("사용자!A:Z")
    return nil if values.nil? || values.empty?
    
    headers = values[0]
    id_index = headers.index("ID")
    col_index = headers.index(column_name)
    return nil unless id_index && col_index
    
    values.each_with_index do |row, index|
      next if index == 0 # 헤더 스킵
      row_id = (row[id_index] || "").gsub('@', '')
      if row_id == clean_user_id
        return row[col_index]
      end
    end
    nil
  end

  def set_stat(user_id, column_name, value)
    clean_user_id = user_id.gsub('@', '')
    
    values = read_values("사용자!A:Z")
    return false if values.nil? || values.empty?
    
    headers = values[0]
    id_index = headers.index("ID")
    col_index = headers.index(column_name)
    return false unless id_index && col_index
    
    values.each_with_index do |row, index|
      next if index == 0 # 헤더 스킵
      row_id = (row[id_index] || "").gsub('@', '')
      if row_id == clean_user_id
        sheet_row = index + 1
        column_letter = number_to_column_letter(col_index + 1)
        range = "사용자!#{column_letter}#{sheet_row}"
        
        result = update_values(range, [[value]])
        return result != nil
      end
    end
    false
  end

  def find_user(user_id)
    clean_user_id = user_id.gsub('@', '')
    
    values = read_values("사용자!A:Z")
    return nil if values.nil? || values.empty?
    
    headers = values[0]
    values.each_with_index do |row, index|
      next if index == 0 # 헤더 스킵
      row_id = (row[0] || "").gsub('@', '')
      if row_id == clean_user_id
        user_data = {}
        headers.each_with_index do |header, col_index|
          user_data[header] = row[col_index]
        end
        return user_data
      end
    end
    nil
  end

  # 통합 조사 시트 관련 메서드 (전투봇 호환)
  def find_investigation_data(target, kind)
    values = read_values("조사!A:K")
    return nil if values.nil? || values.empty?
    
    headers = values[0]
    values.each_with_index do |row, index|
      next if index == 0 # 헤더 스킵
      if row[0] == target # 대상명 매칭 (A열)
        if kind == "조사"
          if ["조사", "DM조사"].include?(row[1]) # 종류 (B열)
            result = {}
            headers.each_with_index { |header, col_index| result[header] = row[col_index] }
            return result
          end
        else
          if row[1] == kind # 종류 매칭 (B열)
            result = {}
            headers.each_with_index { |header, col_index| result[header] = row[col_index] }
            return result
          end
        end
      end
    end
    nil
  end

  private

  def number_to_column_letter(col_num)
    result = ""
    while col_num > 0
      col_num -= 1
      result = ((col_num % 26) + 65).chr + result
      col_num /= 26
    end
    result
  end
end

# 구식 워크시트 객체를 흉내내는 래퍼 클래스 (전투봇 호환용)
class WorksheetWrapper
  def initialize(sheet_manager, title)
    @sheet_manager = sheet_manager
    @title = title
    @data = nil
    load_data
  end

  def load_data
    @data = @sheet_manager.read_values("#{@title}!A:Z")
    @data ||= []
  end

  def save
    true
  end

  def num_rows
    load_data
    @data.length
  end

  def rows
    load_data
    @data
  end

  def [](row, col)
    load_data
    return nil if row < 1 || row > @data.length
    return nil if col < 1 || col > (@data[row-1]&.length || 0)
    @data[row-1][col-1]
  end

  def update_cell(row, col, value)
    column_letter = number_to_column_letter(col)
    range = "#{@title}!#{column_letter}#{row}"
    @sheet_manager.update_values(range, [[value]])
    load_data
  end

  private

  def number_to_column_letter(col_num)
    result = ""
    while col_num > 0
      col_num -= 1
      result = ((col_num % 26) + 65).chr + result
      col_num /= 26
    end
    result
  end
end
