# parttime_bot/sheet_manager.rb
require 'google/apis/sheets_v4'

class SheetManager
  def initialize(service, sheet_id)
    @service = service
    @sheet_id = sheet_id
  end

  def read_values(range)
    @service.get_spreadsheet_values(@sheet_id, range).values || []
  rescue => e
    puts "[에러] 시트 읽기 실패: #{e.message}"
    []
  end

  def write_values(range, values)
    body = Google::Apis::SheetsV4::ValueRange.new(values: values)
    @service.update_spreadsheet_value(@sheet_id, range, body, value_input_option: 'USER_ENTERED')
  rescue => e
    puts "[에러] 시트 쓰기 실패: #{e.message}"
    false
  end

  def find_user(username)
    clean = username.to_s.gsub('@', '').strip
    rows = read_values("사용자!A:M")
    
    return nil if rows.empty?
    
    rows.each_with_index do |row, i|
      next if i == 0
      next if row.nil? || row.empty?
      next if row[0].nil?
      
      row_id = row[0].to_s.gsub('@', '').strip
      
      if row_id == clean
        # 스탯 시트에서 스탯 정보 가져오기
        stats = find_user_stats(clean)
        
        return {
          row_index: i + 1,
          id: row[0].to_s.strip,
          name: row[1].to_s.strip,
          galleons: (row[2] || 0).to_i,
          items: row[3].to_s,
          house: (row[5] || "").to_s.strip,
          luck: stats[:luck],
          agility: stats[:agility],
          attack: stats[:attack],
          defense: stats[:defense]
        }
      end
    end
    
    nil
  end

  def find_user_stats(username)
    clean = username.to_s.gsub('@', '').strip
    rows = read_values("스탯!A:G")
    
    rows.each_with_index do |row, i|
      next if i == 0
      next if row.nil? || row[0].nil?
      
      if row[0].to_s.gsub('@', '').strip == clean
        return {
          luck: (row[4] || 5).to_i,
          agility: (row[3] || 5).to_i,
          attack: (row[5] || 5).to_i,
          defense: (row[6] || 5).to_i
        }
      end
    end
    
    # 기본값
    { luck: 5, agility: 5, attack: 5, defense: 5 }
  end

  def update_galleons(username, amount)
    clean = username.to_s.gsub('@', '').strip
    puts "[갈레온 업데이트] @#{clean} += #{amount}"
    
    rows = read_values("사용자!A:K")
    
    return false if rows.empty?
    
    rows.each_with_index do |row, i|
      next if i == 0
      next if row.nil? || row.empty?
      next if row[0].nil?
      
      row_id = row[0].to_s.gsub('@', '').strip
      
      if row_id == clean
        current = (row[2] || 0).to_i
        new_amount = current + amount
        
        range = "사용자!C#{i + 1}"
        result = write_values(range, [[new_amount]])
        
        if result != false
          puts "[갈레온] #{clean}: #{current} → #{new_amount} (성공)"
          return true
        else
          puts "[갈레온] #{clean}: 업데이트 실패"
          return false
        end
      end
    end
    
    puts "[에러] 사용자 #{clean}을(를) 찾을 수 없음"
    false
  rescue => e
    puts "[에러] update_galleons: #{e.message}"
    puts e.backtrace.first(3).join("\n")
    false
  end
end
