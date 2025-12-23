# commands/job_start_command.rb
require 'time'

class JobStartCommand
  # 쿨타임 관리 (user_id => 마지막 알바 시간)
  @@last_job_time = {}
  COOLDOWN_HOURS = 2

  JOBS = {
    # ===== 일반 아르바이트 =====
    "도서관 사서 보조" => {
      base_pay: 10,
      description: "고서 정리와 금지 서가 목록 관리",
      stat: :luck,
      events: [
        "먼지 낀 고서를 조심스럽게 정리했습니다",
        "책들이 제자리를 찾아가고 있습니다",
        "금지 서가 근처를 신중하게 지나갔습니다",
        "오래된 마법서에서 희미한 빛이 났습니다",
        "목록 작성이 순조롭게 진행됩니다",
        "책장 사이에서 오래된 쪽지를 발견했습니다",
        "조용한 도서관에서 집중해서 일했습니다",
        "분류 작업이 매끄럽게 끝났습니다",
        "두꺼운 책들을 조심히 옮겼습니다",
        "책 냄새가 코를 간질였지만 계속했습니다"
      ]
    },
    "온실 관리 조수" => {
      base_pay: 15,
      description: "3학년 실습용 마법 식물 관리",
      stat: :agility,
      events: [
        "물을 주던 중 덩굴이 살짝 움직였습니다",
        "식물들이 건강하게 자라고 있습니다",
        "가시에 찔릴 뻔했지만 잘 피했습니다",
        "온실 온도를 적절히 조절했습니다",
        "독성 식물을 안전하게 다뤘습니다",
        "뿌리가 엉킨 화분을 정리했습니다",
        "수업 준비를 완벽하게 마쳤습니다",
        "식물 성장 기록을 꼼꼼히 작성했습니다",
        "새싹들이 고개를 내밀기 시작했습니다",
        "흙을 갈아주며 뿌리를 확인했습니다"
      ]
    },
    "우편배달" => {
      base_pay: 12,
      description: "부엉이 우편 분류 및 긴급 배달",
      stat: :agility,
      events: [
        "부엉이들이 협조적이었습니다",
        "편지를 정확한 주소로 분류했습니다",
        "급한 우편을 빠르게 처리했습니다",
        "복도를 달려 제시간에 전달했습니다",
        "비 오는 날이었지만 우편은 무사합니다",
        "부엉이가 다리를 내밀어 편지를 받았습니다",
        "층계를 오르내리며 배달했습니다",
        "수신인을 찾는 데 시간이 걸렸지만 성공했습니다",
        "부엉이 먹이도 챙겨주었습니다",
        "우편 가방을 정리하고 마무리했습니다"
      ]
    },
    "퀴디치 용품 관리" => {
      base_pay: 13,
      description: "경기용 장비 점검 및 정비",
      stat: :attack,
      events: [
        "빗자루 손잡이를 깨끗이 닦았습니다",
        "공들이 제대로 작동하는지 확인했습니다",
        "낡은 장비를 교체 목록에 올렸습니다",
        "보호 장구를 점검하고 수리했습니다",
        "빗자루 빗살을 손질했습니다",
        "경기 준비가 완료되었습니다",
        "창고를 체계적으로 정리했습니다",
        "장비 상태를 기록했습니다",
        "다음 경기를 위해 준비를 마쳤습니다",
        "안전 검사를 꼼꼼히 진행했습니다"
      ]
    },
    "물약 재료 준비" => {
      base_pay: 14,
      description: "고급 물약 재료 세척과 보관",
      stat: :luck,
      events: [
        "재료를 정확한 크기로 자르고 있습니다",
        "약초를 조심스럽게 세척했습니다",
        "보관 용기에 라벨을 붙였습니다",
        "희귀한 재료를 특별 보관했습니다",
        "측정이 정확하게 이루어졌습니다",
        "재고를 확인하고 정리했습니다",
        "썩은 재료를 골라냈습니다",
        "수업 분량을 미리 준비했습니다",
        "냄새가 고약했지만 견뎠습니다",
        "재료실이 깔끔하게 정돈되었습니다"
      ]
    },
    "마법 생물 돌보기" => {
      base_pay: 16,
      description: "3학년 수업용 마법 생물 관리",
      stat: :defense,
      events: [
        "생물들에게 먹이를 주었습니다",
        "우리를 청소하고 점검했습니다",
        "날카로운 발톱을 조심히 피했습니다",
        "생물들이 차분해졌습니다",
        "건강 상태를 확인하고 기록했습니다",
        "위험한 순간을 침착하게 대처했습니다",
        "새끼들을 따로 보살폈습니다",
        "운동장을 깨끗이 치웠습니다",
        "생물들과 신뢰를 쌓았습니다",
        "안전 규칙을 철저히 지켰습니다"
      ]
    },
    "대강당 준비" => {
      base_pay: 11,
      description: "행사 준비 및 식탁 배치 보조",
      stat: :attack,
      events: [
        "무거운 의자를 나르고 배치했습니다",
        "식탁보를 깔끔하게 펼쳤습니다",
        "장식을 정성껏 달았습니다",
        "촛불 위치를 조정했습니다",
        "바닥을 깨끗이 닦았습니다",
        "테이블을 정렬하고 확인했습니다",
        "행사장이 멋지게 꾸며졌습니다",
        "시간 내에 준비를 마쳤습니다",
        "동료와 협력하여 작업했습니다",
        "마지막 점검까지 완료했습니다"
      ]
    },
    "점성술 관측 보조" => {
      base_pay: 17,
      description: "천체 망원경 설치 및 기록 정리",
      stat: :luck,
      events: [
        "망원경을 정확한 각도로 조정했습니다",
        "별의 위치를 차트에 기록했습니다",
        "구름이 걷히기를 기다렸습니다",
        "관측 장비를 점검했습니다",
        "밤하늘이 맑아 관측이 수월했습니다",
        "데이터를 꼼꼼히 정리했습니다",
        "천체의 움직임을 추적했습니다",
        "탑 위의 추운 바람을 견뎠습니다",
        "기록 장부를 정확히 작성했습니다",
        "관측 시간표를 확인하고 준비했습니다"
      ]
    },
    "변신술 교실 정리" => {
      base_pay: 12,
      description: "변신된 물체 복구 및 교구 정리",
      stat: :agility,
      events: [
        "변신된 물건을 원래대로 되돌렸습니다",
        "교구를 체계적으로 정리했습니다",
        "실수로 변신된 것들을 찾아냈습니다",
        "주문이 남아있는 물건을 조심히 다뤘습니다",
        "교실이 깔끔하게 정돈되었습니다",
        "마법 흔적을 청소했습니다",
        "다음 수업 준비를 완료했습니다",
        "부서진 물건은 따로 분류했습니다",
        "변신 실패작들을 수거했습니다",
        "책상을 제자리에 배치했습니다"
      ]
    },
    "기숙사 순찰 보조" => {
      base_pay: 13,
      description: "야간 복도 순찰 및 규율 확인",
      stat: :defense,
      events: [
        "복도를 조용히 순찰했습니다",
        "통행금지 시간을 확인했습니다",
        "어두운 복도에서도 침착했습니다",
        "규칙을 어긴 학생을 발견했습니다",
        "문이 잘 잠겨있는지 확인했습니다",
        "이상한 소리를 주의깊게 들었습니다",
        "손전등으로 구석을 비췄습니다",
        "순찰 일지를 작성했습니다",
        "야간 근무를 무사히 마쳤습니다",
        "다음 순찰조에게 인계했습니다"
      ]
    },

    # ===== 크리스마스 한정 아르바이트 (시급 높음, 난이도 높음) =====
    "루돌프 대신 썰매끌기" => {
      base_pay: 20,
      description: "크리스마스 선물 배달용 썰매 운반 (체력+민첩)",
      stat: :agility,
      secondary_stat: :attack,
      difficulty: :hard,
      events: [
        "썰매가 생각보다 무겁습니다! 끙끙...",
        "눈길이 미끄러워 중심을 잡기 힘듭니다",
        "언덕을 올라가는데 온 힘을 다했습니다",
        "선물 상자가 흔들려 떨어질 뻔했습니다",
        "숨이 차지만 계속 달렸습니다",
        "급커브를 돌다 썰매가 기울었습니다",
        "눈보라가 시야를 가렸습니다",
        "발이 미끄러졌지만 균형을 잡았습니다",
        "썰매 줄이 손에 쓸려 아팠습니다",
        "목적지까지 무사히 도착했습니다!",
        "땀이 흘러 로브가 젖었습니다",
        "다리가 후들거리지만 완주했습니다"
      ]
    },
    "울지 않은 아이 선별하기" => {
      base_pay: 22,
      description: "착한 아이 명단 작성 및 선물 분류 (행운+방어)",
      stat: :luck,
      secondary_stat: :defense,
      difficulty: :hard,
      events: [
        "명단을 꼼꼼히 확인하고 있습니다",
        "아이가 울며 억울하다고 항의합니다",
        "복잡한 사정을 듣고 판단해야 합니다",
        "거짓말을 하는 아이를 가려냈습니다",
        "경계선상의 아이를 고민 중입니다",
        "부모님의 항의 편지를 받았습니다",
        "명단 작성이 지연되고 있습니다",
        "아이들의 눈물에 마음이 약해집니다",
        "공정하게 판단하려 노력했습니다",
        "선물을 받지 못한 아이가 울고 있습니다",
        "기준을 명확히 세우고 작업했습니다",
        "최종 명단을 제출했습니다"
      ]
    },
    "선물 포장하기" => {
      base_pay: 19,
      description: "크리스마스 선물 포장 및 리본 장식 (민첩+행운)",
      stat: :agility,
      secondary_stat: :luck,
      difficulty: :hard,
      events: [
        "포장지를 정확한 크기로 잘랐습니다",
        "리본이 자꾸 풀려서 다시 묶었습니다",
        "테이프가 손에 달라붙었습니다",
        "모서리를 깔끔하게 접었습니다",
        "선물이 너무 크거나 작아 애를 먹었습니다",
        "포장지가 찢어져서 새로 해야 합니다",
        "리본 매듭을 예쁘게 만들었습니다",
        "시간에 쫓겨 서두르고 있습니다",
        "손이 종이에 베여 아팠습니다",
        "완성된 선물이 예쁘게 나왔습니다",
        "포장 재료가 부족해 재고를 확인했습니다",
        "마감 시간 전에 완료했습니다"
      ]
    },
    "트리 장식 도우미" => {
      base_pay: 18,
      description: "대형 크리스마스 트리 장식 설치 (민첩+공격)",
      stat: :agility,
      secondary_stat: :attack,
      difficulty: :hard,
      events: [
        "사다리를 오르며 장식을 달았습니다",
        "높은 곳이라 어지러웠습니다",
        "무거운 장식이 떨어질 뻔했습니다",
        "전구선이 엉켜서 풀었습니다",
        "균형을 잃을 뻔했지만 붙잡았습니다",
        "트리 가지가 부러질까 조심했습니다",
        "장식 위치를 조정하느라 힘들었습니다",
        "별을 꼭대기에 달았습니다",
        "전구가 켜지는지 확인했습니다",
        "트리가 아름답게 완성되었습니다",
        "장식을 떨어뜨려 깨뜨렸습니다",
        "발판이 흔들려 위험했습니다"
      ]
    },
    "크리스마스 케이크 배달" => {
      base_pay: 21,
      description: "특급 크리스마스 케이크 긴급 배달 (민첩+행운)",
      stat: :agility,
      secondary_stat: :luck,
      difficulty: :hard,
      events: [
        "케이크 상자를 조심히 들고 달렸습니다",
        "계단을 뛰어내려가며 중심을 잡았습니다",
        "문을 비켜가느라 몸을 틀었습니다",
        "케이크가 기울지 않게 수평을 유지했습니다",
        "시간이 촉박해 숨이 찼습니다",
        "바닥이 미끄러워 천천히 걸었습니다",
        "장애물을 피해 우회했습니다",
        "케이크 상자 구석이 살짝 찌그러졌습니다",
        "제시간에 도착해 안도했습니다",
        "손님이 만족하며 받아갔습니다",
        "무사히 배달 완료했습니다",
        "다음 주문을 받으러 돌아갔습니다"
      ]
    },
    "산타 수염 관리" => {
      base_pay: 18,
      description: "산타 코스프레용 수염 세탁 및 정리 (행운+민첩)",
      stat: :luck,
      secondary_stat: :agility,
      difficulty: :hard,
      events: [
        "수염에 낀 사탕 부스러기를 제거했습니다",
        "세탁 후 푹신하게 말렸습니다",
        "엉킨 수염을 조심히 빗질했습니다",
        "수염이 찢어지지 않게 조심했습니다",
        "하얀색이 누렇게 변해 표백했습니다",
        "빗질하다 수염이 빠졌습니다",
        "건조기에 넣었더니 줄어들었습니다",
        "완벽하게 복원시켰습니다",
        "다음 행사를 위해 포장했습니다",
        "수염 냄새가 역해 환기시켰습니다",
        "여러 개를 동시에 처리했습니다",
        "마감 전에 모두 완료했습니다"
      ]
    }
  }

  def initialize(mastodon_client, sheet_manager)
    @mastodon_client = mastodon_client
    @sheet_manager = sheet_manager
  end

  def execute(user_id, job_name, reply_status)
    user = @sheet_manager.find_user(user_id)
    
    unless user
      @mastodon_client.reply(
        "@#{user_id} 아직 입학하지 않으셨네요!",
        reply_status['id']
      )
      return
    end

    # 쿨타임 체크
    if on_cooldown?(user_id)
      remaining = cooldown_remaining(user_id)
      @mastodon_client.reply(
        "@#{user_id} 아직 피곤하시군요! #{remaining} 후에 다시 올 수 있어요.",
        reply_status['id']
      )
      return
    end

    # 작업 찾기
    job = JOBS[job_name]
    unless job
      @mastodon_client.reply(
        "@#{user_id} 그런 아르바이트는 없는데요? [알바목록]으로 확인해보세요!",
        reply_status['id']
      )
      return
    end

    # 아르바이트 실행
    result = perform_job(user, job, job_name)
    
    # 쿨타임 기록
    @@last_job_time[user_id] = Time.now
    
    # 결과 메시지 전송
    message = build_result_message(user_id, user[:name] || user_id, job_name, result, job)
    
    # 메시지 길이 체크
    puts "[알바결과] 메시지 길이: #{message.length}자"
    
    @mastodon_client.reply(message, reply_status['id'])
  end

  private

  def on_cooldown?(user_id)
    return false unless @@last_job_time[user_id]
    
    elapsed = Time.now - @@last_job_time[user_id]
    elapsed < (COOLDOWN_HOURS * 3600)
  end

  def cooldown_remaining(user_id)
    elapsed = Time.now - @@last_job_time[user_id]
    remaining_seconds = (COOLDOWN_HOURS * 3600) - elapsed
    hours = (remaining_seconds / 3600).floor
    minutes = ((remaining_seconds % 3600) / 60).ceil
    
    if hours > 0
      "약 #{hours}시간 #{minutes}분"
    else
      "약 #{minutes}분"
    end
  end

  def perform_job(user, job, job_name)
    # 주 스탯
    stat_value = get_stat_value(user, job[:stat])
    
    # 크리스마스 아르바이트는 보조 스탯도 체크
    secondary_bonus = 0
    if job[:secondary_stat]
      secondary_value = get_stat_value(user, job[:secondary_stat])
      secondary_bonus = secondary_value / 10  # 보조 스탯은 10분의 1만 적용
    end
    
    # 4번의 작업 판정
    rolls = []
    total_performance = 0
    
    4.times do |i|
      roll = rand(1..20)
      
      # 크리스마스 아르바이트는 난이도가 높아 보너스 감소
      if job[:difficulty] == :hard
        modified_roll = roll + (stat_value / 7) + secondary_bonus  # 7분의 1로 감소
      else
        modified_roll = roll + (stat_value / 5) + secondary_bonus
      end
      
      # 크리티컬/대실패
      critical = (roll == 20)
      fumble = (roll == 1)
      
      performance = calculate_performance(modified_roll, critical, fumble, job[:difficulty])
      total_performance += performance
      
      event = job[:events].sample
      
      rolls << {
        number: i + 1,
        roll: roll,
        modified: modified_roll,
        performance: performance,
        critical: critical,
        fumble: fumble,
        event: event
      }
    end
    
    # 평균 작업 능률
    avg_performance = total_performance / 4.0
    
    # 최종 급여 계산
    base_pay = job[:base_pay]
    final_pay = (base_pay * (avg_performance / 100.0)).round
    
    # 최소 급여 보장 (크리스마스 아르바이트는 최소 기본급의 50%)
    min_pay = job[:difficulty] == :hard ? (base_pay * 0.5).round : (base_pay * 0.3).round
    final_pay = [final_pay, min_pay].max
    
    # 3연속 고득점 보너스 체크
    bonus = check_streak_bonus(rolls)
    final_pay += bonus if bonus > 0
    
    # 갈레온 실제 반영
    current_galleons = get_current_galleons(user[:id] || user["아이디"])
    new_galleons = current_galleons + final_pay
    @sheet_manager.update_galleons(user[:id] || user["아이디"], new_galleons)
    
    {
      rolls: rolls,
      avg_performance: avg_performance.round(1),
      base_pay: base_pay,
      final_pay: final_pay,
      bonus: bonus,
      is_christmas: job[:difficulty] == :hard
    }
  end

  def calculate_performance(modified_roll, critical, fumble, difficulty = nil)
    return 0 if fumble
    return 100 if critical
    
    # 난이도가 높으면 성공 기준도 높음
    max_roll = difficulty == :hard ? 28 : 25  # 어려운 작업은 더 높은 굴림이 필요
    
    # 수정된 굴림값을 백분율로 변환
    performance = ((modified_roll - 1) * 100.0 / (max_roll - 1)).round
    [0, [performance, 100].min].max
  end

  def check_streak_bonus(rolls)
    consecutive_high = 0
    max_consecutive = 0
    
    rolls.each do |roll|
      if roll[:performance] >= 80
        consecutive_high += 1
        max_consecutive = [max_consecutive, consecutive_high].max
      else
        consecutive_high = 0
      end
    end
    
    return 5 if max_consecutive >= 3
    0
  end

  def get_stat_value(user, stat)
    case stat
    when :luck then (user[:luck] || user["행운"] || 0).to_i
    when :agility then (user[:agility] || user["민첩"] || 0).to_i
    when :attack then (user[:attack] || user["공격"] || 0).to_i
    when :defense then (user[:defense] || user["방어"] || 0).to_i
    else 0
    end
  end

  def get_current_galleons(user_id)
    rows = @sheet_manager.read_values("사용자!A:K")
    return 0 unless rows

    rows.each_with_index do |row, idx|
      next if idx == 0
      if row[0]&.gsub('@', '') == user_id.gsub('@', '')
        return (row[2] || 0).to_i
      end
    end
    0
  end

  def build_result_message(user_id, name, job_name, result, job)
    lines = []
    lines << "@#{user_id}"
    lines << "━━━━━━━━━━━━━━━━━━"
    
    if result[:is_christmas]
      lines << "[크리스마스] #{job_name} 완료"
    else
      lines << "#{job_name} 완료"
    end
    
    lines << "━━━━━━━━━━━━━━━━━━"
    lines << ""
    
    result[:rolls].each do |roll|
      status = if roll[:critical]
                 "[대성공]"
               elsif roll[:fumble]
                 "[실패]"
               elsif roll[:performance] >= 80
                 "[훌륭]"
               elsif roll[:performance] >= 50
                 "[양호]"
               else
                 "[부족]"
               end
      
      lines << "#{roll[:number]}차: [#{roll[:roll]}+보정]=#{roll[:modified]} (#{roll[:performance]}%) #{status}"
      lines << "#{roll[:event]}"
      lines << ""
    end
    
    lines << "━━━━━━━━━━━━━━━━━━"
    lines << "평균 작업률: #{result[:avg_performance]}%"
    lines << "기본급: #{result[:base_pay]}G"
    
    if result[:bonus] > 0
      lines << "보너스: +#{result[:bonus]}G"
    end
    
    lines << "최종: #{result[:final_pay]}G"
    lines << "━━━━━━━━━━━━━━━━━━"
    lines << "쿨타임: #{COOLDOWN_HOURS}시간"
    
    lines.join("\n")
  end
end
