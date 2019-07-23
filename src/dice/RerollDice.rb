# -*- coding: utf-8 -*-

class RerollDice
  def initialize(bcdice, diceBot)
    @bcdice = bcdice
    @diceBot = diceBot
    @nick_e = @bcdice.nick_e
  end

  ####################        個数振り足しダイス     ########################
  def rollDice(string)
    output = ''

    begin
      output = rollDiceCatched(string)
    rescue StandardError => e
      output = "#{string} ＞ " + e.to_s
    end

    return "#{@nick_e}: #{output}"
  end

  def rollDiceCatched(string)
    debug('RerollDice.rollDice string', string)

    successCount = 0
    signOfInequality = ""
    output = ""
    next_roll = 0

    string = string.strip

    m = /^(S)?(\d+R\d+(\+\d+R\d+)*)(\[(\d+)\])?(([<>=]+)(\d+))?(@(\d+))?$/.match(string)
    unless m
      debug("is invaild rdice", string)
      return '1'
    end

    string = m[2]

    signOfInequality, diff = getCondition(m[7], m[8])
    rerollNumber = getRerollNumber(m[5], m[10], diff)
    debug('rerollNumber', rerollNumber)

    debug("diff", diff)

    numberSpot1Total = 0
    dice_cnt_total = 0
    dice_max = 0

    dice_a = string.split("+")
    debug('dice_a', dice_a)

    dice_a.each do |dice_o|
      debug('dice_o', dice_o)

      dice_cnt, dice_max = dice_o.split(/[rR]/).collect { |s| s.to_i }
      debug('dice_cnt', dice_cnt)
      debug('dice_max', dice_max)

      checkReRollRule(dice_max, signOfInequality, diff)

      total, dice_str, numberSpot1, cnt_max, n_max, success, rerollCount =
        @bcdice.roll(dice_cnt, dice_max, (@diceBot.sortType & 2), 0, signOfInequality, diff, rerollNumber)
      debug('bcdice.roll : total, dice_str, numberSpot1, cnt_max, n_max, success, rerollCount',
            total, dice_str, numberSpot1, cnt_max, n_max, success, rerollCount)

      successCount += success
      output += "," if output != ""
      output += dice_str
      next_roll += rerollCount
      numberSpot1Total += numberSpot1
      dice_cnt_total += dice_cnt
    end

    output2, round, success, dice_cnt =
      reRollNextDice(next_roll, dice_max, signOfInequality, diff, rerollNumber)

    successCount += success
    dice_cnt_total += dice_cnt

    output = "#{output}#{output2} ＞ 成功数#{successCount}"
    string += "[#{rerollNumber}]#{signOfInequality}#{diff}"

    debug("string", string)
    output += @diceBot.getGrichText(numberSpot1Total, dice_cnt_total, successCount)

    output = "(#{string}) ＞ #{output}"

    if output.length > $SEND_STR_MAX # 長すぎたときの救済
      output = "(#{string}) ＞ ... ＞ 回転数#{round} ＞ 成功数#{successCount}"
    end

    return output
  end

  def reRollNextDice(next_roll, dice_max, signOfInequality, diff, rerollNumber)
    debug('rerollNumber Begin')

    dice_cnt = next_roll
    debug('dice_cnt', dice_cnt)

    output = ""
    round = 0
    successCount = 0
    dice_cnt_total = 0

    if next_roll <= 0
      return output, round, successCount, dice_cnt_total
    end

    loop do
      total, dice_str, numberSpot1, cnt_max, n_max, success, rerollCount =
        @bcdice.roll(dice_cnt, dice_max, (@diceBot.sortType & 2), 0, signOfInequality, diff, rerollNumber)
      debug('total, dice_str, numberSpot1, cnt_max, n_max, success, rerollCount',
            total, dice_str, numberSpot1, cnt_max, n_max, success, rerollCount)

      successCount += success
      round += 1
      dice_cnt_total += dice_cnt
      dice_cnt = rerollCount
      debug('dice_str', dice_str)
      output += " + #{dice_str}"

      break unless  @bcdice.isReRollAgain(dice_cnt, round)
    end

    debug('output', output)
    debug('rerollNumber End')

    return output, round, successCount, dice_cnt_total
  end

  def getCondition(operator, conditionValue)
    if operator && conditionValue
      operator = @bcdice.marshalSignOfInequality(operator)
      conditionValue = conditionValue.to_i
    elsif (m = /([<>=]+)(\d+)/.match(@diceBot.defaultSuccessTarget))
      operator = @bcdice.marshalSignOfInequality(m[1])
      conditionValue = m[2].to_i
    end

    return operator, conditionValue
  end

  def getRerollNumber(braceThreshold, atmarkThreshold, conditionValue)
    if braceThreshold
      braceThreshold.to_i
    elsif atmarkThreshold
      atmarkThreshold.to_i
    elsif @diceBot.rerollNumber != 0
      @diceBot.rerollNumber
    elsif conditionValue
      conditionValue.to_i
    else
      raiseErroForJudgeRule()
    end
  end

  def raiseErroForJudgeRule()
    raise "条件が間違っています。2R6>=5 あるいは 2R6[5] のように振り足し目標値を指定してください。"
  end

  def checkReRollRule(dice_max, signOfInequality, diff) # 振り足しロールの条件確認
    valid = true

    case signOfInequality
    when '<='
      valid = false if diff >= dice_max
    when '>='
      valid = false if diff <= 1
    when '<>'
      valid = false if (diff > dice_max) || (diff < 1)
    when '<'
      valid = false if diff > dice_max
    when '>'
      valid = false if diff < 1
    end

    unless valid
      raiseErroForJudgeRule()
    end
  end
end
