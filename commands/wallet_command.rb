# commands/wallet_command.rb

class WalletCommand
  def initialize(mastodon_client, sheet_manager)
    @mastodon_client = mastodon_client
    @sheet_manager = sheet_manager
  end

  def execute(user_id, reply_status)
    # 상점봇의 사용자 시트에서 갈레온 확인
    user = find_user_in_shop_sheet(user_id)
    
    unless user
      @mastodon_client.reply(
        "@#{user_id} 아직 입학하지 않으셨네요!",
        reply_status['id']
      )
      return
    end

    message = build_wallet_message(user_id, user)
    @mastodon_client.reply(message, reply_status['id'])
  end

  private

  def find_user_in_shop_sheet(user_id)
    # 상점봇의 "사용자" 시트에서 갈레온 확인
    rows = @sheet_manager.read_values("사용자!A:K")
    return nil unless rows

    headers = rows[0]
    rows.each_with_index do |r, i|
      next if i == 0
      if r[0]&.gsub('@', '') == user_id.gsub('@', '')
        return {
          id: r[0],
          name: r[1],
          galleons: (r[2] || 0).to_i,
          items: (r[3] || "").to_s,
          house: (r[5] || "").to_s
        }
      end
    end
    nil
  end

  def build_wallet_message(user_id, user)
    lines = []
    lines << "@#{user_id}"
    lines << "━━━━━━━━━━━━━━━━━━"
    lines << "#{user[:name]}의 지갑"
    lines << "━━━━━━━━━━━━━━━━━━"
    lines << ""
    lines << "갈레온: #{user[:galleons]}G"
    
    if user[:house] && !user[:house].empty?
      lines << "기숙사: #{user[:house]}"
    end
    
    unless user[:items].empty?
      items = user[:items].split(",").map(&:strip)
      lines << ""
      lines << "소지품:"
      items.each do |item|
        lines << "  • #{item}"
      end
    end
    
    lines << "━━━━━━━━━━━━━━━━━━"
    
    lines.join("\n")
  end
end
