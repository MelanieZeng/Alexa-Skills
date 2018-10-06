require "sinatra"
require 'sinatra/reloader' if development?

require 'alexa_skills_ruby'
require 'httparty'
require 'iso8601'

# ----------------------------------------------------------------------

# Load environment variables using Dotenv. If a .env file exists, it will
# set environment variables from that file (useful for dev environments)
configure :development do
  require 'dotenv'
  Dotenv.load
end

# enable sessions for this project
enable :sessions


# ----------------------------------------------------------------------
#     How you handle your Alexa 
# ----------------------------------------------------------------------

class CustomHandler < AlexaSkillsRuby::Handler

  on_intent("GetZodiacHoroscopeIntent") do
    slots = request.intent.slots
    response.set_output_speech_text("Horoscope Text")
    #response.set_output_speech_ssml("<speak><p>Horoscope Text</p><p>More Horoscope text</p></speak>")
    response.set_reprompt_speech_text("Reprompt Horoscope Text")
    #response.set_reprompt_speech_ssml("<speak>Reprompt Horoscope Text</speak>")
    response.set_simple_card("title", "content")
    logger.info 'GetZodiacHoroscopeIntent processed'
  end

end

# ----------------------------------------------------------------------
#     ROUTES, END POINTS AND ACTIONS
# ----------------------------------------------------------------------


get '/' do
  404
end


# THE APPLICATION ID CAN BE FOUND IN THE 


post '/incoming/alexa' do
  content_type :json

  handler = CustomHandler.new(application_id: ENV['ALEXA_APPLICATION_ID'], logger: logger)

  begin
    hdrs = { 'Signature' => request.env['HTTP_SIGNATURE'], 'SignatureCertChainUrl' => request.env['HTTP_SIGNATURECERTCHAINURL'] }
    handler.handle(request.body.read, hdrs)
  rescue AlexaSkillsRuby::Error => e
    logger.error e.to_s
    403
  end

end


# ----------------------------------------------------------------------
#     ERRORS
# ----------------------------------------------------------------------


error 401 do 
  "Not allowed!!!"
end

# ----------------------------------------------------------------------
#   METHODS
#   Add any custom methods below
# ----------------------------------------------------------------------

private

def update_status status, duration = nil
  
  # gets a corresponding message 
  message = get_message_for status, duration
  # posts it to slack
  post_to_slack status, message
  
end 

def get_message_for status, duration

  # Default response
  message = "other/unknown"
  
  # looks up a message based on the Status provided
  if status == "HERE"
    message = ENV['APP_USER'].to_s + " is in the office."
  elsif status == "BACK_IN"
    message = ENV['APP_USER'].to_s + " will be back in #{(duration/60).round} minutes"
  elsif status == "BE_RIGHT_BACK"
    message = ENV['APP_USER'].to_s + " will be right back"
  elsif status == "GONE_HOME"
    message = ENV['APP_USER'].to_s + " has left for the day. Check back tomorrow."
  elsif status == "DO_NOT_DISTURB"
    message = ENV['APP_USER'].to_s + " is busy. Please do not disturb."
  end
  
  # return the appropriate message
  message
  
end

def post_to_slack status_update, message
  
  # look up the Slack url from the env
  slack_webhook = ENV['SLACK_WEBHOOK']
  
  # create a formatted message 
  formatted_message = "*Status Changed for #{ENV['APP_USER'].to_s} to: #{status_update}*\n" 
  formatted_message += "#{message} " 
  
  # Post it to Slack
  HTTParty.post slack_webhook, body: {text: formatted_message.to_s, username: "OutOfOfficeBot", channel: "back" }.to_json, headers: {'content-type' => 'application/json'}
  
end 