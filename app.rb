# coding: utf-8

require 'eventmachine'
require 'sinatra/base'
require 'figaro'
require 'cinch'

# development
module Rucachan
  class App < Sinatra::Base
    configure :development do
      require 'sinatra/reloader'
      register Sinatra::Reloader
    end
  end
end

# Figaro Setting
# https://github.com/laserlemon/figaro/issues/60
module Figaro
  def path
    @path ||= File.join(Rucachan::App.settings.root, 'config.yml')
  end

  def environment
    Rucachan::App.settings.environment
  end
end
Figaro.env.each { |key, value| ENV[key] = value unless ENV.key?(key) }

# Rucachan!!
module Rucachan
  def self.bot
    @bot
  end

  def self.start
    EventMachine.defer do
      @bot = Cinch::Bot.new do
        configure do |c|
          c.nick = Figaro.env.rucachan_nick || 'rucachan'
          c.user = Figaro.env.rucachan_user || 'rucachan'
          c.realname = Figaro.env.rucachan_realname || 'rucachan'
          c.server = Figaro.env.rucachan_server
          c.port = Figaro.env.rucachan_port
          c.channels = Figaro.env.rucachan_channels.split(/\s*,\s*/)
          c.verbose = true
          c.plugins.plugins = [Rucachan::MessageReceiver]
        end
      end
      @bot.start
    end
  end

  # Plugin: Receiver
  class MessageReceiver
    include Cinch::Plugin

    listen_to :receive_notice
    def listen(m, data)
      @bot.channels.each do |channel|
        if data[:notice_flag]
          Channel(channel).notice data[:message]
        else
          Channel(channel).send data[:message]
        end
      end
    end
  end

  # Web Interface
  class App < Sinatra::Base
    configure do
      Rucachan.start
    end

    # message
    post '/message' do
      unless send(false, request.body.read.to_s.strip)
        status 500
        return 'not running'
      end
      'ok'
    end

    # notice
    post '/notice' do
      unless send(true, request.body.read.to_s.strip)
        status 500
        return 'not running'
      end
      'ok'
    end

    def send(notice_flag, message)
      return false unless Rucachan.bot
      Rucachan.bot.handlers.dispatch(:receive_notice, nil,
        notice_flag: notice_flag,
        message: message.to_s.strip,
      )
      true
    end
  end
end
