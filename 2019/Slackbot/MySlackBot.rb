# coding: utf-8
$LOAD_PATH.unshift(File.dirname(__FILE__))
# encoding: utf-8
require 'open-uri'
require 'sinatra'
require 'SlackBot'

class MySlackBot < SlackBot
  # cool code goes here
  def say_message(msg)
    start = msg.index("「")
    finish = msg.rindex("」と言って")
    if msg[start..finish].include?("「") &&
       msg[start..finish].include?("」と言って") then
      start_two = msg.index("「",start+1)
      finish_two = msg.rindex("」と言って",finish-1)
      if start_two>finish_two then
        start += 1
        finish -= 1
        start_two += 1
        finish_two -= 1
        return msg[start..finish_two] +" " + msg[start_two..finish]
      end
    end
    start += 1
    finish -= 1
    return msg[start..finish]
  end
  
  def gurunavi(msg)
    begin
      uri = "https://api.gnavi.co.jp/RestSearchAPI/v3/"
      acckey = "" #ぐるなびAPIのアクセスキー
      lat = "34.687604"
      long = "133.919713"
      range = "5"
      hit = 5
      max = 5
      if msg.end_with?("で検索")
      then
        $offset = 1
        $freeword = msg[11..-5]
      end
      
      url = uri << "?keyid=" << acckey << "&hit_per_page=5&freeword=" << $freeword << "&latitude=" << lat << "&longitude=" << long << "&range=" << range << "&offset_page=" << $offset.to_s
      url = URI.encode url
      json = open(url)
      hash = JSON.load(json)
      shops = []      
      if hash.has_key?("rest")
        hash["rest"].each do |shop|
          shops.push({
                       name: shop["name"],
                       url: shop["url"],
                       opentime: shop["opentime"],
                       address: shop["address"],
                       budget: shop["budget"]
                     })
        end        
      else
        return "エラーが発生しました．"
      end
      $total = hash["total_hit_count"]
      if hash["total_hit_count"] < hit
      then hit = hash["total_hit_count"]
      end
      if max > hash["total_hit_count"]
      then max = hash["total_hit_count"]
      end
      num = 0
      message = "検索ワード：#{$freeword}\n該当件数：#{hash["total_hit_count"]}\nページ番号：#{$offset}\n\n"
      while num < hit do
        if shops[num][:opentime] == ""
          shops[num][:opentime]="未設定"
        end
        if shops[num][:budget] == ""
          shops[num][:budget]="未設定"
        end
        message << "店名：#{shops[num][:name]}\nURL：#{shops[num][:url]}\n営業時間：#{shops[num][:opentime]}\n住所：#{shops[num][:address]}\n平均予算：#{shops[num][:budget]}\n\n"
        num += 1
      end 
      return message
    rescue 
      return "該当する店舗が存在しません．"
    end
  end

  def status
    return "現在の検索ワード：#{$freeword}\n該当件数：#{$total}\nページ番号：#{$offset}\n\n"
  end

  def jump(msg)
    begin
      if msg.end_with?("previous")
      then $offset -= 1
      elsif msg.end_with?("next")
      then $offset += 1
      elsif msg.length<15
      then return "ページ番号を指定してください．"
      else $offset = msg[15..-1].to_i
      end
      if $offset == 0 || ($total-1)<($offset-1)*5
      then
        $offset = 1
        return "ページが存在しません．1ページ目に戻ります．"
      end
      ret = gurunavi(msg)
      return ret

    rescue
      return "検索ワードが指定されていません．"
    end
  end
  
  def hello
    return "こんにちは zono-botです．\n「◯◯」と言って：◯◯と発言します．\n「◯◯」で検索：◯◯で検索し最大5件の飲食店情報を表示します．\nstatus：現在の検索ワード，該当件数，ページ番号を表示します．\nprevious：前ページの飲食店情報を表示します．\nnext：次ページの飲食店情報を表示します．\njump n：nページ目の飲食店情報を表示します．\n\n"
  end
end

slackbot = MySlackBot.new

set :environment, :production

get '/' do
  "SlackBot Server"
end

post '/slack' do
  content_type :json

  return nil if params[:user_name] == "slackbot" || params[:user_id] == "USLACKBOT"
  
  if params[:text].start_with?("@zono-bot")&&params[:text].include?("「")&&params[:text].include?("」と言って") then
    if params[:text].index("「")<params[:text].rindex("」と言って") then
      params[:text] = slackbot.say_message(params[:text])
    end
    
  elsif params[:text].start_with?("@zono-bot 「")&&params[:text].end_with?("」で検索") then
    params[:text] = slackbot.gurunavi(params[:text])
    
  elsif params[:text].start_with?("@zono-bot jump") || params[:text].end_with?("next") || params[:text].end_with?("previous") then
    params[:text] = slackbot.jump(params[:text])

  elsif params[:text].end_with?("status")then
    params[:text] = slackbot.status
  else
    params[:text] = slackbot.hello
  end
  
  slackbot.post_message(params[:text], username:"zono-bot")
end
