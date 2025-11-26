# commands/job_list_command.rb

class JobListCommand
  # 아르바이트 목록 (실제로는 아이템 시트에서 가져올 예정)
  JOBS = [
    {
      name: "도서관 사서 보조",
      time: "2시간",
      base_pay: 10,
      description: "마담을 도와 책을 정리합니다",
      stat: :luck
    },
    {
      name: "온실 관리 조수",
      time: "3시간",
      base_pay: 15,
      description: "교수님의 식물들을 돌봅니다",
      stat: :agility
    },
    {
      name: "우편배달",
      time: "2시간",
      base_pay: 12,
      description: "부엉이 우편을 분류하고 배달합니다",
      stat: :agility
    },
    {
      name: "퀴디치 용품 관리",
      time: "2시간",
      base_pay: 13,
      description: "교수님의 장비를 정리합니다",
      stat: :attack
    }
  ]

  def initialize(mastodon_client, sheet_manager)
    @mastodon_client = mastodon_client
    @sheet_manager = sheet_manager
  end

  def execute(user_id, reply_status)
    user = @sheet_manager.find_user(user_id)
    
    unless user
      @mastodon_client.reply(
        "@#{user_id} 아직 입학하지 않으셨네요. 먼저 교수님께 입학 신청을 해주세요!",
        reply_status['id']
      )
      return
    end

    message = build_job_list_message(user_id)
    @mastodon_client.reply(message, reply_status['id'])
  end

  private

  def build_job_list_message(user_id)
    lines = []
    lines << "@#{user_id}"
    lines << "━━━━━━━━━━━━━━━━━━"
    lines << "호그와트 아르바이트 목록"
    lines << "━━━━━━━━━━━━━━━━━━"
    lines << ""

    JOBS.each do |job|
      lines << "#{job[:name]} (#{job[:time]})"
      lines << "   #{job[:description]}"
      lines << "   기본 급여: #{job[:base_pay]}갈레온"
      lines << "   판정 스탯: #{stat_korean(job[:stat])}"
      lines << ""
    end

    lines << "사용법: [알바시작/이름]"
    lines << "예: [알바시작/도서관 사서 보조]"
    
    lines.join("\n")
  end

  def stat_korean(stat)
    case stat
    when :luck then "행운"
    when :agility then "민첩"
    when :attack then "공격"
    when :defense then "방어"
    else "행운"
    end
  end
end
