#!/bin/env ruby

# adds lib/ to require path
$:.unshift File.expand_path('../../lib', __FILE__)

require 'sinatra'
require 'sitediff'

get '/diff' do
  return 503 unless params[:url] 
  return SiteDiff::Page.new(params[:url]).diff()
end

get '/complement' do
  return 503 unless params[:url] 
  return SiteDiff::Page.complement_url(params[:url])
end
