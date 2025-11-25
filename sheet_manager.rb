# sheet_manager.rb
require 'google/apis/sheets_v4'
require 'googleauth'

class SheetManager
  def initialize(sheet_id, credentials_path)
    @sheet_id = sheet_id
    @service = Google::Apis::SheetsV4::SheetsService.new
    @service.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: File.open(credentials_path),
      scope: Google::Apis::SheetsV4::AUTH_SPREADSHEETS
    )
  end

  # 시트 읽기
  def read_values(range)
    response = @service.get_spreadsheet_values(@sheet_id, range)
    response.values
  rescue => e
    puts "[시트 읽기 오류] #{e.message}"
    nil
  end

  # 시트 쓰기
  def update_values(range, values)
    value_range = Google::Apis::SheetsV4::ValueRange.new(values: values)
    @service.update_spreadsheet_value(
      @sheet_id,
      range,
      value_range,
      value_input_option: 'USER_ENTERED'
    )
  rescue => e
    puts "[시트 쓰기 오류] #{e.message}"
  end

  # 사용자 찾기
  def find_user(user_id)
    rows = read_values("스탯!A:Z")
    return nil unless rows

    headers = rows[0]
    rows.each_with_index do |r, i|
      next if i == 0
      if r[0]&.gsub('@', '') == user_id.gsub('@', '')
        return convert_user_row(headers, r, i + 1)
      end
    end
    nil
  end

  # 사용자 업데이트
  def update_user(user_id, updates)
    rows = read_values("스탯!A:Z")
    return false unless rows

    headers = rows[0]
    rows.each_with_index do |row, idx|
      next if idx == 0
      next unless row[0]&.gsub('@', '') == user_id.gsub('@', '')

      updates.each do |key, value|
        header_name = case key.to_sym
                      when :id then "ID"
                      when :name then "이름"
                      when :hp then "HP"
                      when :agility then "민첩"
                      when :luck then "행운"
                      when :attack then "공격"
                      when :defense then "방어"
                      else key.to_s
                      end

        col = headers.index(header_name)
        next unless col
        row[col] = value
      end

      update_values("스탯!A#{idx+1}:Z#{idx+1}", [row])
      return true
    end
    false
  end

  # 아르바이트 목록 가져오기
  def get_jobs
    rows = read_values("아이템!A:Z")
    return [] unless rows

    headers = rows[0]
    jobs = []

    rows.each_with_index do |r, i|
      next if i == 0
      next if r[0].nil?

      # 아르바이트 항목만 필터링 (설명에 "아르바이트" 또는 "알바" 포함)
      description = (r[3] || "").to_s
      next unless description.include?("아르바이트") || description.include?("알바")

      jobs << {
        name: r[0].to_s.strip,
        price: (r[1] || 0).to_i,
        description: description.strip,
        difficulty: extract_difficulty(description)
      }
    end

    jobs
  end

  private

  def convert_user_row(headers, row, row_num)
    data = { _row: row_num }
    headers.each_with_index do |h, i|
      data[h] = row[i]
      
      key = case h
            when "ID" then :id
            when "이름" then :name
            when "HP" then :hp
            when "민첩" then :agility
            when "행운" then :luck
            when "공격" then :attack
            when "방어" then :defense
            else nil
            end
      
      data[key] = row[i] if key
    end
    data
  end

  def extract_difficulty(description)
    return "쉬움" if description.include?("쉬운") || description.include?("간단한")
    return "보통" if description.include?("보통") || description.include?("일반")
    return "어려움" if description.include?("어려운") || description.include?("힘든")
    "보통"
  end
end
