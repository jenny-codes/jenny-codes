class StaticsController < ApplicationController
  def about
    @page = {
      description: 'ABOUT'
    }
    @to_write = [
      ['Rails 中的神奇指令們',                    '讓你用一行指令就莫名其妙完成所有事情'],
      ['「用 Ruby on Rails 開發一個網頁程式」系列',  '就用這個網站當例子，大概會至少有三篇吧'],
      ['Ruby 的「syntax sugar」',                 'Ruby 語言中白吃的午餐'],
      ['如何在 Rails 中匯入 Bootstrap Theme',       '給像我一樣的前端苦手'],
      ['Rails 的 Model 繼承關係',                   '如今才暸解資料庫的學問真的不能小覷'],
      ['Rails 的 MVC 架構',                         'Model, View, Controller '],
      ['Rails on Heroku',                          '把寫好的程式推上線（部署到雲端）的眉眉角角'],
    ]
  end

  def resources
    @page = {
      description: 'RESOURCES'
    }
  end
end