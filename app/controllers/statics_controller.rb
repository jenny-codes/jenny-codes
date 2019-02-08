class StaticsController < ApplicationController
  def about
    @page = {
      description: 'ABOUT'
    }
  end

  def resources
    @page = {
      description: 'RESOURCES'
    }
  end
end